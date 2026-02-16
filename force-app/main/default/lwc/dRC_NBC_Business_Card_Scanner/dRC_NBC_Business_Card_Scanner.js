import { LightningElement, track } from 'lwc';
import processBusinessCard from '@salesforce/apex/DRC_NBC_BusinessCard_Controller.processBusinessCard';
import IMAGE_COMPRESSION from '@salesforce/resourceUrl/DRC_NBC_Compressjs';
import { loadScript } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import createLead from '@salesforce/apex/DRC_NBC_BusinessCard_Controller.createLead';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DRC_NBC_Business_Card_Scanner extends NavigationMixin(LightningElement) {
    @track imageSrc = null;  // To hold the image data
    @track apiResponse = null;  // To hold the API response
    @track error;
    imageCompressionLibInitialized = false;
    isLoading = false;
    @track isReadOnly = true;
    renderedCallback() {
        if (this.imageCompressionLibInitialized) {
            return;
        }
        this.imageCompressionLibInitialized = true;

        loadScript(this, IMAGE_COMPRESSION)
            .then(() => {
                console.log('Image compression library loaded successfully');
            })
            .catch(error => {
                console.error('Error loading image compression library', error);
            });
    }

    // Handle file input change (uploading a business card image)
    handleFileChange(event) {
        this.isLoading = true;
        const file = event.target.files[0];
        console.log('file : ' + file);
        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                console.log('size : ' + file.size);
                if (file.size > 1048576) { // If file size is greater than 1MB
                    this.compressImage(file);
                    console.log('in compress')
                } else {
                    this.imageSrc = reader.result; // Display the uploaded image
                    this.handleScan();
                    console.log('direct');
                }
                //this.imageSrc = reader.result; // Display the uploaded image
            };
            reader.readAsDataURL(file);
        }
    }
    async compressImage(file) {
        const options = {
            maxSizeMB: 1,
            maxWidthOrHeight: 1920,
            useWebWorker: true
        };
        try {
            const compressedFile = await window.imageCompression(file, options);
            const reader = new FileReader();
            reader.onload = () => {
                console.log('size : ' + reader.result);
                this.imageSrc = reader.result;
                this.handleScan();
            }
            reader.readAsDataURL(compressedFile);
        } catch (error) {
            console.error('Error compressing image', error);
        }
    }

    // Handle the scan button click, calling the API through Apex
    handleScan() {
        console.log('Image :' + this.imageSrc);
        processBusinessCard({ imageUrl: this.imageSrc })
            .then(result => {
                this.apiResponse = JSON.parse(result);
                console.log('data : ' + JSON.stringify(this.apiResponse));
                this.isLoading = false;
            })
            .catch(error => {
                this.error = JSON.stringify(error);
                this.isLoading = false;
                console.error('Error:', error);
            });
    }


    toggleEdit() {
        this.isReadOnly = !this.isReadOnly;
    }

    handleInputChange(event) {
        console.log('event + ' + event.target.name);
        this.apiResponse[event.target.name] = event.target.value;
        console.log(JSON.stringify(this.apiResponse));
    }

 /*   handleCreateLead() {
        if (!this.apiResponse['name']) {
            this.showToastMessage('Error', 'Name is required.', 'error');
        } else {
            let nameArray = this.apiResponse['name'].trim().split(' ', 2);
            if (nameArray.length !== 2) {
                this.showToastMessage('Error', 'Please provide both first and last name. Example: John Doe', 'error');
            }
        }
        if (!this.apiResponse['company_name']) {
            this.showToastMessage('Error', 'Company Name is required.', 'error');
        }
        const leadData = {
            name: this.apiResponse.name,
            jobTitle: this.apiResponse.job_title,
            companyName: this.apiResponse.company_name,
            phoneNumber: this.apiResponse.phone_numbers,
            email: this.apiResponse.email_addresses,
            address: this.apiResponse.address,
            websiteUrl: this.apiResponse.website_url,
            city : this.apiResponse.city,
            country: this.apiResponse.country,
            street : this.apiResponse.street,
            postalCode : this.apiResponse.postal_code,
            state : this.apiResponse.state
        };

        createLead({ leadWrapper: leadData })
            .then(leadId => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: leadId,
                        objectApiName: 'Lead',
                        actionName: 'view'
                    },
                });
                console.log('Lead created with ID:', leadId);
                this.showToastMessage('Success', result.message, 'success');

            })
            .catch(error => {
                console.error('Error creating lead:', error);
                // Handle error (e.g., show an error message)
            });
    }*/

    handleCreateLead() {
    if (!this.apiResponse['name']) {
        this.showToastMessage('Error', 'Name is required.', 'error');
        return;
    }

    const nameArray = this.apiResponse['name'].trim().split(' ', 2);
    if (nameArray.length !== 2) {
        this.showToastMessage('Error', 'Please provide both first and last name. Example: John Doe', 'error');
        return;
    }

    if (!this.apiResponse['company_name']) {
        this.showToastMessage('Error', 'Company Name is required.', 'error');
        return;
    }

    const leadData = {
        name: this.apiResponse.name,
        jobTitle: this.apiResponse.job_title,
        companyName: this.apiResponse.company_name,
        phoneNumber: this.apiResponse.phone_numbers,
        email: this.apiResponse.email_addresses,
        address: this.apiResponse.address,
        websiteUrl: this.apiResponse.website_url,
        city: this.apiResponse.city,
        country: this.apiResponse.country,
        street: this.apiResponse.street,
        postalCode: this.apiResponse.postal_code,
        state: this.apiResponse.state
    };

    createLead({ leadWrapper: leadData })
        .then(response => {
            const result = JSON.parse(response);
            if (result.status === 'success') {
                this.showToastMessage('Success', result.message, 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result.leadId,
                        objectApiName: 'Lead',
                        actionName: 'view'
                    }
                });
            } 
            else if (result.status === 'duplicate') {
                this.showToastMessage('Error', result.message, 'Error');
                // No navigation on duplicate
            }
        })
        .catch(error => {
            console.error('Error creating lead:', error);
            this.showToastMessage('Error', 'An error occurred while creating the Lead.', 'error');
        });
    } 


    showToastMessage(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
}