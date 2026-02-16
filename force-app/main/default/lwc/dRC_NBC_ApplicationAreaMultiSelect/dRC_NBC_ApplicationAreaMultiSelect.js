import { LightningElement, api, wire, track } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import FORM_FACTOR from "@salesforce/client/formFactor";
import getApplicationAreaValues from '@salesforce/apex/DRC_NBC_ApplicationAreaController.getApplicationAreaValues';

export default class DRC_NBC_ApplicationmultiSelectPicklist extends LightningElement{

    @api label;    
    @api selectedInput;      // Flow input
    @track selectedValues = [];
    @api selectedOutput;     // Flow output

    @track options = [];

    isMobile = false;
    isDesktop = false;

    // Fetch picklist values from Apex
    @wire(getApplicationAreaValues)
    wiredValues({ error, data }) {
        if (data) {
            this.options = data.map(item => ({
                label: item.label,
                value: item.value,
                checked: this.selectedValues.includes(item.value)
            }));
        } else if (error) {
            console.error('Error fetching application area picklist:', error);
        }
    }

    connectedCallback() {
        // Device logic
        if (FORM_FACTOR === "Large" || FORM_FACTOR === "Medium") {
            this.isDesktop = true;
        } else {
            this.isMobile = true;
        }

        // Preselect values from Flow input
        if (this.selectedInput) {
            this.selectedValues = this.selectedInput.split(";");

            this.updateOptionCheckedStates();
        }
    }

    handleChange(event) {
        const value = event.target.value;

        if (event.target.checked) {
            this.selectedValues = [...this.selectedValues, value];
        } else {
            this.selectedValues = this.selectedValues.filter(v => v !== value);
        }

        this.updateOptionCheckedStates();
        this.dispatchOutput();
    }

    updateOptionCheckedStates() {
        this.options = this.options.map(opt => ({
            ...opt,
            checked: this.selectedValues.includes(opt.value)
        }));
    }

    dispatchOutput() {
        const selectedNames = this.options
            .filter(opt => this.selectedValues.includes(opt.value))
            .map(opt => opt.label);

        this.selectedOutput = selectedNames.join(';');

        this.dispatchEvent(
            new FlowAttributeChangeEvent('selectedOutput', this.selectedOutput)
        );
    }

    @api
    handleFlowSubmit() {
        this.dispatchOutput();
    }
}