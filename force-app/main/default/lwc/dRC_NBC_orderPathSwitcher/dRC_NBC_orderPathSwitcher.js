import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import ORDER_OBJECT from '@salesforce/schema/Order';
import SAMPLE_STATUS_FIELD from '@salesforce/schema/Order.DRC_NBC_Sample_Status__c';

const FIELDS = [
    'Order.DRC_NBC_Sample_Status__c'
];

export default class Drc_nbc_orderPathSwitcher extends LightningElement {
    @api recordId;
    currentStatus;
    recordTypeId;
    picklistSteps = [];

    // Fetch Order record
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredOrder({ data, error }) {
        if (data) {
            this.currentStatus = data.fields.DRC_NBC_Sample_Status__c.value;
        } else if (error) {
            console.error('Error fetching order record:', error);
        }
    }

    // Get record type ID of Order object
    @wire(getObjectInfo, { objectApiName: ORDER_OBJECT })
    objectInfo({ data, error }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        } else if (error) {
            console.error('Error fetching object info:', error);
        }
    }

    // Get picklist values for DRC_NBC_Sample_Status__c
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: SAMPLE_STATUS_FIELD })
    wiredPicklist({ data, error }) {
        if (data) {
            this.picklistSteps = data.values.map(item => item.label);
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }

    get stepItems() {
        return this.picklistSteps.map(step => {
            let cssClass = 'slds-path__item';
            if (this.isCompleted(step)) {
                cssClass += ' slds-is-complete';
            } else if (this.isActive(step)) {
                cssClass += ' slds-is-current slds-is-active';
            } else {
                cssClass += ' slds-is-incomplete';
            }
            return { step, cssClass };
        });
    }

    isActive(step) {
        return this.currentStatus === step;
    }

    isCompleted(step) {
        const steps = this.picklistSteps;
        const currentIndex = steps.indexOf(this.currentStatus);
        const stepIndex = steps.indexOf(step);
        return stepIndex < currentIndex;
    }
}