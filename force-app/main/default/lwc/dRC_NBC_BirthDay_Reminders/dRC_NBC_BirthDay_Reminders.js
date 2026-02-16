import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import getCategorizedBirthdays from '@salesforce/apex/DRC_NBC_BirthDayFilter.getCategorizedBirthdays';
import getContactEmail from '@salesforce/apex/DRC_NBC_BirthDayFilter.getContactEmail';
import LOGO from '@salesforce/resourceUrl/DRC_NBC_DR_Logo';

export default class DRC_NBC_Birthday_Reminders extends NavigationMixin(LightningElement) {
    @track todaysBirthdays = [];
    @track weeksBirthdays = [];
    @track monthsBirthdays = [];
    @track yearsBirthdays = [];

    email = '';
    contactName = '';
    
    columnsWithDate = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Birthdate', fieldName: 'FormattedBirthdate'},
        { label: 'Account Name', fieldName: 'AccountName'},
        {
            label: 'Send Email',
            fieldName: 'Email',
            type: 'button-icon',
            typeAttributes: {
                iconName: 'utility:email',
                name: 'send_email',
                title: 'Send Email',
                alternativeText: 'Send Email',
            }
        }
    ];
    

    connectedCallback() {
        getCategorizedBirthdays()
            .then(result => {
                console.log('getCategorizedBirthdays result', JSON.stringify(result));
                
                // Format all data sets with both contact formatting and birthdate formatting
                this.todaysBirthdays = this.formatContacts(this.formatBirthdates(result.today || []));
                this.weeksBirthdays = this.formatContacts(this.formatBirthdates(result.week || []));
                this.monthsBirthdays = this.formatContacts(this.formatBirthdates(result.month || []));
                this.yearsBirthdays = this.formatContacts(result.year || []);
            })
            .catch(error => {
                console.error('Error fetching birthday data: ', error);
            });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        console.log('actionName: ', actionName);
        console.log('row: ', row);
        if (actionName === 'send_email') {
            this.navigateToEmailComposer(row.Id);
        }
    }

    navigateToEmailComposer(contactId) {
        console.log('Entered navigateToEmailComposer');        
        console.log('contactId: ', contactId);

        getContactEmail({ contactId: contactId })
    .then(result => {
        console.log('getContactEmail result: ', result);
        // this.email = result.Email;
        this.contactName = result.Name;
        console.log('this.contactName: ', this.contactName);
        const logoUrl = 'https://drcresins--nbcdev--c.sandbox.vf.force.com/resource/1757053255000/DRC_NBC_DR_Logo';
        
        var pageRef = {
            type: "standard__quickAction",
            attributes: {
                apiName: "Global.SendEmail",
            },
            state: {
                recordId: contactId,
                defaultFieldValues: encodeDefaultFieldValues({
                    Subject: 'Birthday greetings from DR',
                    ToAddress: this.email,
                    HtmlBody: `
                        <p>Dear ${this.contactName},</p>
                        <p>
                            On behalf of all of us at <strong>DR</strong>, we'd like to wish you a very 
                            Happy Birthday! 🎂✨
                        </p>
                        <p>
                            We truly appreciate your trust and support, and we're grateful to have you as part of 
                            our family. May this year bring you success, happiness, and wonderful opportunities—
                            both personally and professionally.
                        </p>
                        <p>Here's to celebrating you today! 🥂</p>
                        <br/>
                        <p>Warm regards,</p>
                        <p>The <strong>DR</strong> Team</p>
                        <img src="${logoUrl}" alt="DR' Logo" style="height: 50px; width: auto;" />
                    `,
                }),
            },
        };
        this[NavigationMixin.Navigate](pageRef);
    })
    .catch(error => {
        console.error('Error fetching email: ', error);
    });
    }

    formatContacts(contacts) {
        return contacts.map(contact => {
            contact.AccountName = contact.Account ? contact.Account.Name : '';
            return contact;
        });
    }

    formatBirthdates(contacts) {
        return contacts.map(contact => {
            const birthdate = contact.Birthdate;
            if (birthdate) {
                const dateObj = new Date(birthdate);
                const day = String(dateObj.getDate()).padStart(2, '0');
                const month = dateObj.toLocaleString('default', { month: 'short' });
                contact._sortDate = dateObj;
                contact.FormattedBirthdate = `${day}-${month}`;
            } else {
                contact.FormattedBirthdate = '';
            }
            console.log('contact.FormattedBirthdate: ', contact.FormattedBirthdate);    
            return contact;
        })
        .sort((a, b) => {
            const aMonthDay = a._sortDate.getMonth() * 100 + a._sortDate.getDate();
            const bMonthDay = b._sortDate.getMonth() * 100 + b._sortDate.getDate();
            return aMonthDay - bMonthDay; 
        })
        .map(contact => {
            delete contact._sortDate;
            return contact;
        });
    }
    
}