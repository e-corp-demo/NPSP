import getFieldMappingSet from '@salesforce/apex/BDI_MappingServiceAdvanced.getFieldMappingSet';
import getNamespaceWrapper from '@salesforce/apex/BDI_ManageAdvancedMappingCtrl.getNamespaceWrapper';
import { handleError } from 'c/utilTemplateBuilder';

class GeTemplateBuilderService {
    fieldMappingByDevName = null;
    fieldMappingsByObjMappingDevName = null;
    objectMappingByDevName = null;
    namespaceWrapper = null;

    init = async (fieldMappingSetName, refresh) => {
        if (this.fieldMappingByDevName === null ||
            this.fieldMappingsByObjMappingDevName === null ||
            this.objectMappingByDevName === null ||
            refresh === true) {
            await this.handleGetFieldMappingSet(fieldMappingSetName);
        }

        if (this.namespaceWrapper === null || refresh === true) {
            await this.handleGetNamespaceWrapper();
        }
    }

    /*******************************************************************************
    * @description Method makes an imperative apex call and populates various
    * field and object maps using the class BDI_MappingServiceAdvanced.
    *
    * @param {string} fieldMappingSetName: Name of a Data_Import_Field_Mapping_Set__mdt
    * record.
    *
    * @return {object} promise: Promise from the imperative apex call
    * getFieldMappingSet.
    */
    handleGetFieldMappingSet = (fieldMappingSetName) => {
        return new Promise((resolve, reject) => {
            getFieldMappingSet({ fieldMappingSetName: fieldMappingSetName })
                .then(data => {
                    this.fieldMappingByDevName = data.fieldMappingByDevName;
                    this.objectMappingByDevName = data.objectMappingByDevName;
                    this.fieldMappingsByObjMappingDevName = data.fieldMappingsByObjMappingDevName;

                    this.addWidgetsPlaceholder(this.fieldMappingByDevName,
                        this.objectMappingByDevName,
                        this.fieldMappingsByObjMappingDevName);

                    resolve(data);
                })
                .catch(error => {
                    handleError(error);
                    reject(error);
                });
        });
    }

    /*******************************************************************************
    * @description Method makes an imperative apex call and populates the
    * namespaceWrapper property.
    *
    * @return {object} promise: Promise from the imperative apex call
    * getNamespaceWrapper.
    */
    handleGetNamespaceWrapper = () => {
        return new Promise((resolve, reject) => {
            getNamespaceWrapper()
                .then(data => {
                    this.namespaceWrapper = data;
                    resolve(data);
                })
                .catch(error => {
                    handleError(error);
                    reject(error);
                })
        });
    }

    // TODO: Replace or delete later when actual widgets are in place.
    /*******************************************************************************
    * @description Placeholder method for mocking widgets in the UI.
    *
    * @param {object} fieldMappingByDevName: Map of field mappings.
    * @param {object} objectMappingByDevName: Map of object mappings.
    */
    addWidgetsPlaceholder = (fieldMappingByDevName,
        objectMappingByDevName,
        fieldMappingsByObjMappingDevName) => {

        fieldMappingByDevName.geCreditCardWidget = {
            DeveloperName: 'geCreditCardWidget',
            MasterLabel: 'Credit Card',
            Target_Object_Mapping_Dev_Name: 'Widgets',
            Target_Field_Label: 'Credit Card',
            Required: 'No',
            Element_Type: 'widget',
        }

        objectMappingByDevName.Widgets = {
            DeveloperName: 'Widgets',
            MasterLabel: 'Widgets'
        }

        fieldMappingsByObjMappingDevName.Widgets = [
            fieldMappingByDevName.geCreditCardWidget
        ]
    }
}

export default new GeTemplateBuilderService();