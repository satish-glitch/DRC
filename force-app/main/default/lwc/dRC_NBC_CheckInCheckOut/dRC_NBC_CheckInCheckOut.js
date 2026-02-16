import { LightningElement,track, api } from 'lwc';
import getTaskRecord from '@salesforce/apex/DRC_NBC_CheckInCheckOut_Task_Controller.getTaskRecord';
import getEventRecord from '@salesforce/apex/DRC_NBC_CheckInCheckOut_Event_Controller.getEventRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';
import updateTask from '@salesforce/apex/DRC_NBC_CheckInCheckOut_Task_Controller.updateTask';
import updateEvent from '@salesforce/apex/DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent';
import getCoordinatesForRecord from '@salesforce/apex/DRC_NBC_GeoapifyService.getCoordinatesForRecord';

export default class DRC_NBC_CheckInCheckOut extends LightningElement {
   // @apiavailableActions = [];
    @track latitude;
    @track longitude;
    @track accuracy;
    @track lastUpdated;
    @track errorMessage;
    @track isLoading = true;
    @api recordId;
    @track distance;
    @track compliant;
    @track noncompliant;
    compliance;
    checkedInComment;
    checkedOutCommnet;
    textAreaLable;
    statusIn;
    statusOut;
    buttonLabel;
    taskRecord;
    

    connectedCallback() {
        console.log('Record ID: ' + this.recordId);
        if (this.recordId) {
            if (this.recordId.startsWith('00T')) {
                this.getCurrentTask();
            } else if (this.recordId.startsWith('00U')) {
                this.getCurrentEvent();
            }
        }
    }

    getCurrentTask() {
        getTaskRecord({ recordId: this.recordId })
            .then((result) => {
                this.taskRecord = result;
                if (this.taskRecord.DRC_NBC_Is_CheckedIn__c) {
                    this.statusOut = 'You are Checking Out';
                    this.textAreaLable = 'Checking Out Comment';
                    this.buttonLabel = 'Check-Out';
                } else {
                    this.statusIn = 'You are Checking In';
                    this.textAreaLable = 'Checking In Comment';
                    this.buttonLabel = 'Check-In';
                }
            })
            .then(() => this.getCurrentPosition())
            .catch((error) => {
                console.error('Error fetching task record:', JSON.stringify(error));
            });
    }

    getCurrentEvent() {
        getEventRecord({ recordId: this.recordId })
            .then((result) => {
                this.taskRecord = result;
                if (this.taskRecord.DRC_NBC_Is_CheckedIn__c) {
                    this.statusOut = 'You are Checking Out';
                    this.textAreaLable = 'Checking Out Comment';
                    this.buttonLabel = 'Check-Out';
                } else {
                    this.statusIn = 'You are Checking In';
                    this.textAreaLable = 'Checking In Comment';
                    this.buttonLabel = 'Check-In';
                }
            })
            .then(() => this.getCurrentPosition())
            .catch((error) => {
                console.error('Error fetching event record:', JSON.stringify(error));
            });
    }

    // ✅ Get user's current GPS location
    getCurrentPosition() {
        this.isLoading = true;

        navigator.geolocation.getCurrentPosition(
            (position) => {
                this.latitude = position.coords.latitude;
                this.longitude = position.coords.longitude;
                this.accuracy = position.coords.accuracy;
                this.lastUpdated = new Date(position.timestamp).toLocaleString();

                console.log('📍 Current Location:', this.latitude, this.longitude);

                // Now fetch the reference coordinates (Lead/Contact/Account)
                this.fetchReferenceCoordinates();
                this.isLoading = false;
            },
            (error) => {
                this.errorMessage = error.message;
                this.isLoading = false;
                console.error('Location Error:', error);
            }
        );
    }

    /**
     * ✅ Fetch Geoapify coordinates based on record address
     */
    fetchReferenceCoordinates() {
    console.log('📡 Fetching coordinates from Apex for record:', this.recordId);


    getCoordinatesForRecord({ recordId: this.recordId })
        .then((result) => {
            if (result && result.latitude && result.longitude) {
                console.log('✅ Geoapify Coordinates:', JSON.stringify(result));
                this.distance = this.calculateDistance(
                    this.latitude,
                    this.longitude,
                    result.latitude,
                    result.longitude
                );
            } else {
                console.warn('⚠️ No coordinates returned.');
            }
        })
        .catch((error) => {
            console.error('❌ Error in getCoordinatesForRecord:', JSON.stringify(error));
        })
        .finally(() => {
            setTimeout(() => {
                this.isLoading = false;
            }, 30000); 
        });
    }

    // ✅ Calculate distance (in KM)
    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371.0; // Radius of Earth (km)
        const dLat = this.toRadians(lat2 - lat1);
        const dLon = this.toRadians(lon2 - lon1);
        const a =
            Math.sin(dLat / 2) ** 2 +
            Math.cos(this.toRadians(lat1)) *
                Math.cos(this.toRadians(lat2)) *
                Math.sin(dLon / 2) ** 2;
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distance = R * c;
        console.log(`📏 Distance: ${distance.toFixed(2)} KM`);

        if (distance > 2) {
            this.noncompliant = 'Non Compliant';
            this.compliance = false;
        } else {
            this.compliant = 'Compliant';
            this.compliance = true;
        }

        return distance.toFixed(2) + ' KM';
    }

    toRadians(deg) {
        return (deg * Math.PI) / 180;
    }

    handleChange(event) {
        if (this.taskRecord.DRC_NBC_Is_CheckedIn__c) {
            this.checkedOutCommnet = event.target.value;
        } else {
            this.checkedInComment = event.target.value;
        }
    }

    handleClick() {
    const isTask = this.recordId.startsWith('00T');
    const isEvent = this.recordId.startsWith('00U');
    const isCheckedIn = this.taskRecord.DRC_NBC_Is_CheckedIn__c;
    const comment = isCheckedIn ? this.checkedOutCommnet : this.checkedInComment;
    const successMessage = isCheckedIn
        ? 'You have Checked-Out successfully'
        : 'You have Checked-In successfully';

    const updateFn = isTask ? updateTask : updateEvent;

    const cleanDistance = this.distance ? this.distance.replace(' KM', '').trim() : '0';

    updateFn({
        recordId: this.recordId,
        latitude: this.latitude,
        longitude: this.longitude,
        distance: cleanDistance,
        commnent: comment,
        comp: this.compliance
    })
        .then((result) => {   // ✅ FIXED: Added 'result' parameter
            console.log('✅ Update result:', JSON.stringify(result));

            // Update UI state
            this.taskRecord.DRC_NBC_Is_CheckedIn__c = result.isCheckedIn;
            this.taskRecord.DRC_NBC_Is_Checked_Out__c = result.isCheckedOut;

            // Show toast with compliance info
            const toastVariant =             this.compliance == false ? 'warning' : 'success';
            const toastMessage =             this.compliance == false
                ? `${successMessage} (⚠️ Non-Compliant)`
                : `${successMessage} (✅ Compliant)`;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: toastMessage,
                    variant: toastVariant,
                    mode: 'dismissable'
                })
            );

            this.dispatchEvent(new FlowNavigationFinishEvent());
        })
        .catch((err) => {
            console.error('❌ Error updating record:', JSON.stringify(err));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: err.body ? err.body.message : 'Error updating record',
                    variant: 'error'
                })
            );
        });
}


}