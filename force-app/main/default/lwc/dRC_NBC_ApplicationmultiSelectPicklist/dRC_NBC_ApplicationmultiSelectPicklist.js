import { LightningElement, api, track } from 'lwc';
export default class DRC_NBC_ApplicationmultiSelectPicklist extends LightningElement {

    @api label;
    @api optionsJson;         // Input from Flow
    @api value;               // Output to Flow

    @track options = [];
    @track filteredOptions = [];
    @track selectedItems = [];

    searchKey = '';
    showDropdown = false;

    connectedCallback() {
        try {
            let arr = JSON.parse(this.optionsJson); 
            this.options = arr.map(x => ({
                label: x,
                value: x,
                checked: false
            }));

            this.filteredOptions = [...this.options];
        } catch (e) {
            console.error('Invalid JSON passed', e);
        }
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();

        this.filteredOptions = this.options
            .filter(opt => opt.label.toLowerCase().includes(this.searchKey))
            .map(o => ({
                ...o,
                checked: this.selectedItems.some(s => s.value === o.value)
            }));
    }

    handleSelect(event) {
        const value = event.target.value;
        const option = this.options.find(o => o.value === value);

        if (event.target.checked) {
            this.selectedItems = [...this.selectedItems, option];
        } else {
            this.selectedItems = this.selectedItems.filter(i => i.value !== value);
        }

        this.updateFlowValue();
    }

    handleSelectAll() {
        this.selectedItems = [...this.options];
        this.filteredOptions = this.options.map(o => ({ ...o, checked: true }));
        this.updateFlowValue();
    }

    handleClearAll() {
        this.selectedItems = [];
        this.filteredOptions = this.options.map(o => ({ ...o, checked: false }));
        this.updateFlowValue();
    }

    removeSelected(event) {
        const value = event.detail.name;

        this.selectedItems = this.selectedItems.filter(i => i.value !== value);

        this.filteredOptions = this.filteredOptions.map(o => ({
            ...o,
            checked: this.selectedItems.some(i => i.value === o.value)
        }));

        this.updateFlowValue();
    }

    updateFlowValue() {
        this.value = this.selectedItems.map(i => i.value).join(';');

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: this.value
            })
        );
    }
}