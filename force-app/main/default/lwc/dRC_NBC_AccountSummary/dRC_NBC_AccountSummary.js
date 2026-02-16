import { LightningElement, api, wire } from 'lwc';
import getAccountMetrics from '@salesforce/apex/DRC_NBC_AccountSummary.getAccountMetrics';

export default class DRC_NBC_AccountSummary extends LightningElement {
    @api recordId;
    accountMetrics = {};
    orderMetrics = {};
    error;
    @wire(getAccountMetrics, { accountId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.accountMetrics = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            console.error('Error fetching account accountMetrics:', error);
        }
    }

    get formattedWonAmount() {
        return this.formatAmount(this.accountMetrics.wonAmount, 'indian'); // or 'international'
    }

    get formattedLostAmount() {
        return this.formatAmount(this.accountMetrics.lostAmount, 'indian'); // or 'international'
    }

    get formattedTotalAmount() {
        return this.formatAmount(this.accountMetrics.totalAmount, 'indian'); // or 'international'
    }

    get formattedDraftOrderAmount() {
        return this.formatAmount(this.accountMetrics.totalDraftOrdersAmount, 'indian');
    }

    get formattedClosedOrderAmount() {
        return this.formatAmount(this.accountMetrics.totalClosedOrdersAmount, 'indian');
    }

    get formattedCancelledOrderAmount() {
        return this.formatAmount(this.accountMetrics.totalCancelledOrdersAmount, 'indian');
    }

    get formattedOpenOrderAmount() {
        return this.formatAmount(this.accountMetrics.totalOpenOrdersAmount, 'indian');
    }

    formatAmount(amount, formatStyle = 'international') {
        if (typeof amount !== 'number') return amount;

        if (formatStyle === 'indian') {
            if (amount >= 1e7) return (amount / 1e7).toFixed(1) + ' Cr';
            if (amount >= 1e5) return (amount / 1e5).toFixed(1) + ' Lakh';
            if (amount >= 1e3) return (amount / 1e3).toFixed(1) + ' K';
            return amount.toString();
        } else {
            if (amount >= 1e9) return (amount / 1e9).toFixed(1) + 'B';
            if (amount >= 1e6) return (amount / 1e6).toFixed(1) + 'M';
            if (amount >= 1e3) return (amount / 1e3).toFixed(1) + 'K';
            return amount.toString();
        }
    }
}