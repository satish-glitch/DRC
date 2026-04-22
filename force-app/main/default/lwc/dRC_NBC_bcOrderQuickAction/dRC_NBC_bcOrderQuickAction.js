import { LightningElement, api } from 'lwc';
import triggerBCIntegration from '@salesforce/apex/DRC_NBC_OrderBCController.triggerBCIntegration';
import getLatestLog from '@salesforce/apex/DRC_NBC_OrderBCController.getLatestLog';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class DRC_NBC_bcOrderQuickAction extends LightningElement {
    @api recordId;
    isLoading = true;

    _pollCount            = 0;
    _maxPolls             = 6;
    _pollInterval         = 5000;
    _integrationStartTime = null; // ✅ timestamp captured before trigger fires

    connectedCallback() {
        const url = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = recordIdMatch ? recordIdMatch[1] : null;

        if (!this.recordId) {
            this.showToast('Error', 'No Order Id provided', 'error');
            this.closeAction();
            return;
        }

        // ✅ Capture NOW before the callout — ensures we never read logs older than this sync
        this._integrationStartTime = new Date().toISOString();

        triggerBCIntegration({ orderId: this.recordId })
            .then((integrationResult) => {

                // ── HARD FAILURE returned synchronously ────────────────────
                if (
                    integrationResult == null ||
                    integrationResult?.startsWith('FAILURE') ||
                    integrationResult?.startsWith('ERROR')
                ) {
                    this.isLoading = false;
                    this.showToast('Error', integrationResult || 'Integration returned no result.', 'error');
                    this.closeAction();

                // ── ALL OTHER PATHS ────────────────────────────────────────
                // Account sync, Order push, Order update, Queued
                // Always poll the latest log — covers both Account and Order logs
                } else {
                    this._pollCount = 0;
                    const delay = integrationResult?.startsWith('QUEUED') ? this._pollInterval : 3000;
                    setTimeout(() => this.pollLog(), delay);
                }
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Integration call failed', 'error');
                this.closeAction();
            });
    }

    /**
     * Polls the latest DRC_NBC_API_Log__c record scoped to this Order.
     * Passes orderId + afterDateTime so Apex only returns a log that:
     *   - belongs to this Order OR its related Account (via DRC_NBC_Created_Updated_SF_Id__c)
     *   - was created AFTER this integration was triggered (no stale logs)
     * Parses JSON/SOAP response body to extract a human-readable message.
     * ERROR   → parsed message from Response Body
     * SUCCESS → parsed message from Response Body
     * Retries up to _maxPolls times if no log found yet.
     */
    pollLog() {
        this._pollCount++;

        // ✅ Pass orderId + startTime — Apex filters by sfId AND timestamp
        getLatestLog({
            orderId       : this.recordId,
            afterDateTime : this._integrationStartTime
        })
            .then((log) => {
                if (log) {
                    this.isLoading = false;
                    const logType = (log.DRC_NBC_Log_Type__c || '').toUpperCase();
                    const parsed  = this.extractMessage(
                        log.DRC_NBC_Response_Body__c,
                        log.DRC_NBC_Error_Message__c
                    );

                    if (logType.includes('ERROR')) {
                        this.showToast('Error', parsed, 'error');

                    } else if (logType.includes('SUCCESS')) {
                        let successMessage = 'Successfully synced';

                        if (logType.includes('ACCOUNT')) {
                            successMessage = 'Account successfully synced';
                        } else if (logType.includes('ORDER')) {
                            successMessage = 'Order successfully synced';
                        }

                        this.showToast('Success', successMessage, 'success');

                    } else {
                        this.showToast('Info', 'Order sync in progress, please refresh after a few minutes.', 'info');
                    }

                    this.closeAction();

                } else if (this._pollCount < this._maxPolls) {
                    // Log not written yet — still running, retry after interval
                    setTimeout(() => this.pollLog(), this._pollInterval);

                } else {
                    // Timed out after all retries
                    this.isLoading = false;
                    this.showToast('Warning', 'Read timeout — order sync in progress, please refresh after a few minutes.', 'warning');
                    this.closeAction();
                }
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Failed to fetch integration log.', 'error');
                this.closeAction();
            });
    }

    /**
     * Parses the BC response body and extracts a clean readable message.
     *
     * Handles these response shapes:
     *
     *   SOAP/XML  → extracts <faultstring> text from SOAP Fault envelope
     *
     *   JSON:
     *     {"error": {"code": "...", "message": "Actual error text"}}
     *     {"message": "..."}
     *     {"Message": "..."}   ← BC sometimes capitalises
     *
     *   Plain non-JSON/non-XML string (returned as-is)
     *
     * Falls back to errorMsg field, then a generic message if both are empty.
     */
    extractMessage(responseBody, errorMsg) {
        if (responseBody) {

            // ── SOAP / XML response ────────────────────────────────────────
            if (responseBody.trim().startsWith('<')) {
                try {
                    const parser = new DOMParser();
                    const xmlDoc = parser.parseFromString(responseBody, 'text/xml');

                    // Use querySelector to handle namespace-prefixed tags (s:Fault, s:Body etc.)
                    const faultString = xmlDoc.querySelector('Fault faultstring')
                                     || xmlDoc.querySelector('faultstring');
                    if (faultString?.textContent) {
                        return faultString.textContent;
                    }

                    // Fallback: <detail><string>
                    const detailString = xmlDoc.querySelector('detail string')
                                      || xmlDoc.querySelector('string');
                    if (detailString?.textContent) {
                        return detailString.textContent;
                    }

                } catch (e) {
                    // XML parse failed — fall through and return raw body
                }
                return responseBody;
            }

            // ── JSON response ──────────────────────────────────────────────
            try {
                const parsed = JSON.parse(responseBody);

                // {"error": {"message": "..."}}  — most common BC error shape
                if (parsed.error?.message) {
                    return parsed.error.message;
                }
                // {"message": "..."}
                if (parsed.message) {
                    return parsed.message;
                }
                // {"Message": "..."}  — BC capitalised variant
                if (parsed.Message) {
                    return parsed.Message;
                }
                // Parsed successfully but no known message field
                return JSON.stringify(parsed);

            } catch (e) {
                // Not JSON — return plain string as-is
                return responseBody;
            }
        }

        // Response body empty — fall back to error message field
        return errorMsg || 'Integration failed. Please check logs.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}