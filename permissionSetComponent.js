import { LightningElement, track, wire} from 'lwc';
import getObjects from '@salesforce/apex/PermissionSetController.getObjects';
import getFieldsData from '@salesforce/apex/PermissionSetController.getFieldsData';
import getPermissionSets from '@salesforce/apex/PermissionSetController.getPermissionSets';
import updatePermissions from '@salesforce/apex/PermissionSetController.updatePermissions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
const columns = [
    {label : 'Read', value : 'Read'},
    {label : 'Edit', value : 'Edit'},
    {label : 'No Access', value : 'NoAccess'}
];

const columnsForObject = [
    {label : 'Read', value : 'PermissionsRead'},
    {label : 'Create', value : 'PermissionsCreate'},
    {label : 'Edit', value : 'PermissionsEdit'},
    {label : 'Delete', value : 'PermissionsDelete'},
    {label : 'View All', value : 'PermissionsViewAllRecords'},
    {label : 'Modify All', value : 'PermissionsModifyAllRecords'},
];

export default class PermissionSetComponent extends LightningElement {
    @track displaySpinner = true;
    @track objects;
    @track error;
    @track fieldsData;
    @track PermissionSetData;
    @track columns = columns;
    @track columnsForObject = columnsForObject;
    @track selectedPermission = 'Read';
    @track selectedObject = 'Account';
    @track selectedObjectPermission = ['PermissionsRead'];
    @wire(getObjects)
    wiredObjects({ error, data }) {
        if (data) {
            this.objects = data;
            this.error = undefined;
            this.displaySpinner = false;
        } else if (error) {
            this.error = error;
            this.objects = undefined;
            this.displaySpinner = false;
            this.showToast('Error!',JSON.stringify(error),'error','dismissable');
        }
    }
    @wire(getPermissionSets)
    getPermissionSets({ error, data }) {
        if (data) {
            this.PermissionSetData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.PermissionSetData = undefined;
            this.showToast('Error!',JSON.stringify(error),'error','dismissable');
        }
    }

    connectedCallback(){
        this.getFieldsOfObject('Account');
    }

    handleObjectChange(event){
        this.displaySpinner = true;
        this.selectedObject = event.detail.value;
        this.getFieldsOfObject(this.selectedObject);
    }
    getFieldsOfObject(objName){
        getFieldsData({
            "objName" : objName,
        })
        .then(result => {
            this.fieldsData = result;
            this.displaySpinner = false;
        })
        .catch(error => {
            this.showToast('Error!',JSON.stringify(error),'error','dismissable');
            this.displaySpinner = false;
        });
    }

    handleColumnChange(event){
        this.selectedPermission = event.detail.value;
    }

    handleObjectPermissionChange(event){
        this.selectedObjectPermission = event.detail.value;
    }

    handleClick(event){ 
        this.displaySpinner = true;
        let selectedFields = '';
        let selectedSets = '';
        let selectedPermissions = '';
        let selectedRows = this.template.querySelectorAll('lightning-input');
        for(let i = 0; i < selectedRows.length; i++) {
            if(selectedRows[i].checked && selectedRows[i].type === 'checkbox') {
                if(selectedRows[i].dataset.id === '2'){
                    selectedFields = selectedFields + selectedRows[i].value + ';';
                }
                else if(selectedRows[i].dataset.id === '1'){
                    selectedSets = selectedSets + selectedRows[i].value + ';';
                }
            }
        }

        for(let i = 0; i < this.selectedObjectPermission.length; i++){
            selectedPermissions = selectedPermissions + this.selectedObjectPermission[i] + ';';
        }

        if(selectedSets === ''){
            this.showToast('Alert!','Please Select atleast on permisssion Set.','warning','dismissable');
            this.displaySpinner = false;
        }
        else if(selectedFields === '' && selectedPermissions === ''){
            this.showToast('Alert!','Please select the entity to which permission should be given.','warning','dismissable');
            this.displaySpinner = false;
        }
        else{
            updatePermissions({
                "objName" : this.selectedObject,
                "perm" : this.selectedPermission,
                "selectedFields" : selectedFields,
                "selectedSets" : selectedSets,
                "objPerm" : selectedPermissions
            })
            .then(result => {
                this.showToast('Success!','Permissions Updated.','success','dismissable');
                this.displaySpinner = false;
            })
            .catch(error => {
                this.showToast('Error!',JSON.stringify(error),'error','dismissable');
                this.displaySpinner = false;
            });
        }
    }
    showToast(titleText,messageText,variantText,mode) {
        const event = new ShowToastEvent({
            title: titleText,
            message: messageText,
            variant : variantText,
            mode : mode
        });
        this.dispatchEvent(event);
    }
}