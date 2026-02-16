import { LightningElement, api, wire, track } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import FORM_FACTOR from "@salesforce/client/formFactor";
import getEventProductNames from '@salesforce/apex/DRC_NBC_ProductController.getEventProductNames';

export default class DRC_NBC_MultiSelectPicklist extends LightningElement {
    @api selectedInput;
    @track selectedValues = [];
    @api selectedOutput;

    @track options = [];
    deviceType;
    isMobile = false;
    isDesktop = false;

    @wire(getEventProductNames)
    wiredProducts({ error, data }) {
        if (data) {
            this.options = data;
            this.updateOptionCheckedStates();
        } else if (error) {
            console.error('Error fetching active products:', error);
        }
    }

    connectedCallback() {
        if (FORM_FACTOR === "Large" || FORM_FACTOR === "Medium") {
            this.deviceType = "Desktop/Laptop";
            this.isDesktop = true;
        } else if (FORM_FACTOR === "Small") {
            this.deviceType = "Mobile";
            this.isMobile = true;
        }
    }

    handleChange(event) {
        const value = event.target.value;
        if (event.target.checked) {
            this.selectedValues = [...this.selectedValues, value];
        } else {
            this.selectedValues = this.selectedValues.filter(val => val !== value);
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

  /*  dispatchOutput() {
        this.selectedOutput = this.selectedValues;
        this.dispatchEvent(
            new FlowAttributeChangeEvent('selectedOutput', this.selectedOutput)
        );
    }*/

    get selected() {
        return this.selectedValues.join(';');
    }

   /* @api
    handleFlowSubmit() {
        // No "other" logic needed anymore
        this.selectedOutput = this.selectedValues;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedOutput', this.selectedOutput));
    }*/

    dispatchOutput() {
        // Convert selected value IDs to corresponding labels (names)
        const selectedNames = this.options
            .filter(opt => this.selectedValues.includes(opt.value))
            .map(opt => opt.label);

        // Return names only, as semicolon-separated string
        this.selectedOutput = selectedNames.join(';');

        this.dispatchEvent(
            new FlowAttributeChangeEvent('selectedOutput', this.selectedOutput)
        );
    }

    @api
    handleFlowSubmit() {
        const selectedNames = this.options
            .filter(opt => this.selectedValues.includes(opt.value))
            .map(opt => opt.label);

        this.selectedOutput = selectedNames.join(';');

        this.dispatchEvent(
            new FlowAttributeChangeEvent('selectedOutput', this.selectedOutput)
        );
    }



}