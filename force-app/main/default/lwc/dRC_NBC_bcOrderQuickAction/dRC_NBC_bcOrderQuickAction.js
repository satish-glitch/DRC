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
    _integrationStartTime = null;

    connectedCallback() {
        const url = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = recordIdMatch ? recordIdMatch[1] : null;

        if (!this.recordId) {
            this.showToast('Error', 'No Order Id provided', 'error');
            this.closeAction();
            return;
        }

        // Capture timestamp before trigger fires — ensures no stale logs are read
        this._integrationStartTime = new Date().toISOString();

        triggerBCIntegration({ orderId: this.recordId })
            .then((integrationResult) => {

                // Hard failure returned synchronously
                if (
                    integrationResult == null ||
                    integrationResult?.startsWith('FAILURE') ||
                    integrationResult?.startsWith('ERROR')
                ) {
                    this.isLoading = false;
                    this.showToast('Error', integrationResult || 'Integration returned no result.', 'error');
                    this.closeAction();

                } else {
                    // All other paths — poll the log
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

    pollLog() {
        this._pollCount++;

        getLatestLog({
            orderId       : this.recordId,
            afterDateTime : this._integrationStartTime
        })
            .then((log) => {
                if (log) {
                    this.isLoading = false;

                    // DRC_NBC_Log_Type__c has two values: 'Error' or 'Success'
                    const logType = (log.DRC_NBC_Log_Type__c || '').trim().toLowerCase();

                    if (logType === 'error') {
                        // Parse BC response body for a human-readable error message
                        const errorMessage = this.extractMessage(
                            log.DRC_NBC_Response_Body__c,
                            log.DRC_NBC_Error_Message__c
                        );
                        this.showToast('Error', errorMessage, 'error');

                    } else if (logType === 'success') {
                        // Parse BC response body for success message
                        const successMessage = this.extractMessage(
                            log.DRC_NBC_Response_Body__c,
                            null
                        );
                        // If BC returns a meaningful message use it, else show generic
                        this.showToast(
                            'Success',
                            successMessage || 'Successfully synced to Business Central.',
                            'success'
                        );

                    } else {
                        // Unexpected log type value — treat as in-progress
                        this.showToast(
                            'Info',
                            'Sync in progress, please refresh after a few minutes.',
                            'info'
                        );
                    }

                    this.closeAction();

                } else if (this._pollCount < this._maxPolls) {
                    // Log not written yet — still running, retry
                    setTimeout(() => this.pollLog(), this._pollInterval);

                } else {
                    // Timed out after all retries
                    this.isLoading = false;
                    this.showToast(
                        'Warning',
                        'Read timeout — sync in progress, please refresh after a few minutes.',
                        'warning'
                    );
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
     * Handles:
     *   SOAP/XML  → extracts <faultstring> text
     *   JSON      → {"error": {"message": "..."}}
     *              {"message": "..."}
     *              {"Message": "..."}   BC capitalised variant
     *   Plain string → returned as-is
     *
     * Falls back to errorMsg field, then generic message.
     */
    extractMessage(responseBody, errorMsg) {
        if (responseBody) {

            // SOAP / XML response
            if (responseBody.trim().startsWith('<')) {
                try {
                    const parser = new DOMParser();
                    const xmlDoc = parser.parseFromString(responseBody, 'text/xml');

                    const faultString = xmlDoc.querySelector('Fault faultstring')
                                     || xmlDoc.querySelector('faultstring');
                    if (faultString?.textContent) {
                        return faultString.textContent;
                    }

                    const detailString = xmlDoc.querySelector('detail string')
                                      || xmlDoc.querySelector('string');
                    if (detailString?.textContent) {
                        return detailString.textContent;
                    }

                } catch (e) {
                    // XML parse failed — fall through
                }
                return responseBody;
            }

            // JSON response
            try {
                const parsed = JSON.parse(responseBody);

                // {"error": {"message": "..."}} — most common BC error shape
                if (parsed.error?.message) {
                    return parsed.error.message;
                }
                // {"message": "..."}
                if (parsed.message) {
                    return parsed.message;
                }
                // {"Message": "..."} — BC capitalised variant
                if (parsed.Message) {
                    return parsed.Message;
                }
                // Parsed but no known message field — stringify
                return JSON.stringify(parsed);

            } catch (e) {
                // Not JSON — return plain string
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