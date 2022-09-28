import apexAddToElevateBatch from '@salesforce/apex/GE_GiftEntryController.addToElevateBatch';
import apexCreateElevateBatch from '@salesforce/apex/GE_GiftEntryController.createElevateBatch';
import apexRemoveFromElevateBatch from '@salesforce/apex/GE_GiftEntryController.removeFromElevateBatch';
import PAYMENT_ELEVATE_ID from '@salesforce/schema/DataImport__c.Payment_Elevate_ID__c';
import PAYMENT_ELEVATE_ELEVATE_BATCH_ID from '@salesforce/schema/DataImport__c.Payment_Elevate_Batch_Id__c';

class ElevateBatch {

    constructor() {
        this.elevateBatchId = null;
    }
    
    async add(tokenizedGift) {
        return await this.performAdd(tokenizedGift, true);
    }

    async performAdd(tokenizedGift, retryOnFailure) {
        try {
            if (!this.elevateBatchId) {
                this.elevateBatchId = await this.create();
            }

            return await apexAddToElevateBatch(
                {batchItemRequestDTO: tokenizedGift, elevateBatchId: this.elevateBatchId}
            );
        } catch (exception) {
            if (retryOnFailure) {
                this.elevateBatchId = await this.create();
                return await this.performAdd(tokenizedGift, false);
            } else {
                throw(exception);
            }
        }
    }

    async create() {
        const elevateBatch = await apexCreateElevateBatch();
        return elevateBatch.elevateBatchId;
    }

    async remove(authorizedGift) {
        return await apexRemoveFromElevateBatch({
            batchItem: {
                elevateBatchId: authorizedGift[PAYMENT_ELEVATE_ELEVATE_BATCH_ID.fieldApiName],
                id: authorizedGift[PAYMENT_ELEVATE_ID.fieldApiName]
            }
        });
    }
}

export default ElevateBatch;