import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateAccountManager from '@salesforce/apex/DRC_NBC_ConsigneeBank_ActionController.updateAccountManager';
import getLatestLog from '@salesforce/apex/DRC_NBC_ConsigneeBank_ActionController.getLatestLog';

export default class DrcNbcSyncConsigneeBank extends LightningElement {
    @api recordId;
    isExecuting = false;

    @api
    async invoke() {
        if (this.isExecuting) {
            return;
        }

        this.isExecuting = true;
        const startedAt = new Date().toISOString();

        try {
            await updateAccountManager({
                recordId: this.recordId
            });

            const latestLog = await this.waitForLatestLog(startedAt);

            if (latestLog) {
                this.showLogToast(latestLog);
            } else {
                this.showToast(
                    'Info',
                    'Account Manager update started, but latest API log is not available yet.',
                    'info'
                );
            }
        } catch (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isExecuting = false;
        }
    }

    async waitForLatestLog(startedAt) {
        const maxAttempts = 12;
        const delayMs = 2500;

        for (let i = 0; i < maxAttempts; i++) {
            const log = await getLatestLog({
                recordId: this.recordId,
                afterDateTime: startedAt
            });

            if (log) {
                return log;
            }

            await this.sleep(delayMs);
        }

        return null;
    }

    showLogToast(log) {
        const logType = log.DRC_NBC_Log_Type__c
            ? log.DRC_NBC_Log_Type__c.toLowerCase()
            : '';

        const responseBody = log.DRC_NBC_Response_Body__c || '';
        const errorMessage = log.DRC_NBC_Error_Message__c || '';

        // Success case
        if (logType.includes('success')) {
            this.showToast(
                'Success',
                'Sales Person Successfully updated.',
                'success'
            );
            return;
        }

        // Error case
        if (logType.includes('error')) {
            const message =
                this.extractSoapFaultMessage(errorMessage) ||
                this.extractSoapFaultMessage(responseBody) ||
                errorMessage ||
                responseBody ||
                'Sales Person update failed.';

            this.showToast(
                'Error',
                this.truncateMessage(message),
                'error'
            );
            return;
        }

        this.showToast(
            'Info',
            'Account Manager update completed, but log type is not Success or Error.',
            'info'
        );
    }

    extractSoapFaultMessage(xmlString) {
        if (!xmlString) {
            return null;
        }

        const decodedXml = this.decodeHtmlEntities(xmlString);

        const faultStringMatch = decodedXml.match(
            /<faultstring[^>]*>([\s\S]*?)<\/faultstring>/i
        );

        if (faultStringMatch && faultStringMatch[1]) {
            return this.cleanXmlValue(faultStringMatch[1]);
        }

        const detailStringMatch = decodedXml.match(
            /<string[^>]*>([\s\S]*?)<\/string>/i
        );

        if (detailStringMatch && detailStringMatch[1]) {
            return this.cleanXmlValue(detailStringMatch[1]);
        }

        return null;
    }

    cleanXmlValue(value) {
        return this.decodeHtmlEntities(value)
            .replace(/<[^>]*>/g, '')
            .replace(/\s+/g, ' ')
            .trim();
    }

    decodeHtmlEntities(value) {
        if (!value) {
            return '';
        }

        return value
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&amp;/g, '&')
            .replace(/&quot;/g, '"')
            .replace(/&#39;/g, "'");
    }

    truncateMessage(message) {
        if (!message) {
            return 'No response message found in latest API log.';
        }

        return message.length > 500
            ? message.substring(0, 500) + '...'
            : message;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong while updating Sales Person.';
    }
}