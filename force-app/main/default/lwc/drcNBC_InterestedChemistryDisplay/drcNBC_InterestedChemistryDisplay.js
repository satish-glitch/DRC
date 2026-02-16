import { LightningElement, api } from 'lwc';

export default class DrcNBC_InterestedChemistryDisplay extends LightningElement {
    @api chemistryValue; // Can be a semicolon-separated string or a Flow collection (array)
    get chemistryList() {
        console.log('Received chemistryValue:', this.chemistryValue);
        let values = [];
        if (Array.isArray(this.chemistryValue)) {
            this.chemistryValue.forEach(item => {
                if (typeof item === 'string') {
                    values.push(...item.split(';').map(val => val.trim()).filter(Boolean));
                }
            });
            return values;
        }
        if (typeof this.chemistryValue === 'string' && this.chemistryValue.trim() !== '') {
            return this.chemistryValue.split(';').map(item => item.trim()).filter(Boolean);
        }
        return [];
    }
}