/*
    Copyright (c) 2009, Salesforce.com Foundation
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Salesforce.com Foundation nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.com Foundation
* @date 2015
* @description Tests Contact Merge when done through the API
* @group ContactMerge
*/

@isTest
public with sharing class CON_ContactMergeTDTM_TEST {

    /*********************************************************************************************************
    * @description if you only want to run one test in this class, fill in its name here.
    * if you want to run all tests, then use '*'
    */
    private static string strTestOnly = '*';
        
    /*******************************************************************************************************
    * @description merge two Contacts in the same Household Account.  
    * verify: 
    *   the account's names and greetings are updated.
    *   Soft Credits are recalculated.
    *   Opportunity Rollups on Contact are recalculated
    *   No Duplicate and Primary Affiliations
    */
    static testMethod void mergeContactsSameHHAccount() {
        if (strTestOnly != '*' && strTestOnly != 'mergeContactsSameHHAccount') return;
        
        // this creates 1 Household Accounts, with 2 Contacts, and a default Address for each HH
        ADDR_Addresses_TEST.createHHTestData(1, 2);
        
        // create an opp for each contact
        list<Opportunity> listOpp = UTIL_UnitTestData_TEST.OppsForContactList(ADDR_Addresses_TEST.listConT, null, 
            UTIL_UnitTestData_TEST.getclosedWonStage(), system.Today(), 100, null, null);
        insert listOpp;
        
        Contact conWinner = ADDR_Addresses_TEST.listConT[1];
        Contact conLoser = ADDR_Addresses_TEST.listConT[0];

        // create a primary affiliation for each contact
        npe5__Affiliations_Settings__c affiliationsSettingsForTests = UTIL_CustomSettingsFacade.getAffiliationsSettingsForTests(
            new npe5__Affiliations_Settings__c(npe5__Automatic_Affiliation_Creation_Turned_On__c = true));
        Account accOrg = new Account(Name='OrgAccount');
        insert accOrg;
        conWinner.Primary_Affiliation__c = accOrg.Id;
        conLoser.Primary_Affiliation__c = accOrg.Id;
        AFFL_Affiliations_TDTM.doNotRunForContacts = false;
        AFFL_Affiliations_TDTM.hasRunForAccounts = false;
        AFFL_Affiliations_TDTM.hasRunForAffiliations = false;
        update new list<Contact> {conWinner, conLoser};        
        AFFL_Affiliations_TDTM.doNotRunForContacts = false;
        AFFL_Affiliations_TDTM.hasRunForAccounts = false;
        AFFL_Affiliations_TDTM.hasRunForAffiliations = false;
        system.assertEquals(2, [select count() from npe5__Affiliation__c]);              
        
        Test.startTest();
        merge conWinner conLoser;

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our contacts and accounts
        list<Account> listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, 
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account where Name <> 'OrgAccount' order by Id]);
        list<Contact> listCon = [select Id, Firstname, AccountId, npo02__NumberOfClosedOpps__c,
            is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Firstname];
            
        // verify the merge
        system.assertEquals(1, listAcc.size());
        system.assertEquals(1, listCon.size());
        system.assertEquals(conWinner.Id, listCon[0].Id);
                    
        // verify the account's names and greetings are updated
        system.assertEquals(false, listAcc[0].npo02__Formal_Greeting__c.contains(conLoser.Firstname));        
        system.assertEquals(true, listAcc[0].npo02__Formal_Greeting__c.contains(conWinner.Firstname));    
        
        // verify opps still in the account
        system.assertEquals(2, [select count() from Opportunity where AccountId = :listAcc[0].Id]);  
            
        // verify Account rollups are still valid
        system.assertEquals(2, listAcc[0].npo02__NumberOfClosedOpps__c);  
        
        // verify Contact rollups are valid
        system.assertEquals(2, listCon[0].npo02__NumberOfClosedOpps__c);          

        // verify Soft Credits recalculated
        system.assertEquals(2, [select count() from OpportunityContactRole where ContactId = :listCon[0].Id]);        
        system.assertEquals(2, [select count() from OpportunityContactRole where isPrimary = true]);        
        system.assertEquals(2, [select count() from OpportunityContactRole]);  
        
        // verify no duplicate Affiliations and one primary Affiliation
        system.assertEquals(1, [select count() from npe5__Affiliation__c where npe5__Primary__c = true]);              
        system.assertEquals(1, [select count() from npe5__Affiliation__c]);              
    }

    /*******************************************************************************************************
    * @description merge two Contacts from different Household Accounts.  
    * verify: 
    *   the account's names and greetings are updated.
    *   Opps are moved to the Winning Contact's account
    *   Soft Credits are recalculated.
    *   Opp Rollups are recalculated.
    *   Addresses are dealt with
    *   No Duplicate and Primary Affiliations
    */
    static testMethod void mergeContactsDifferentHHAccount() {
        if (strTestOnly != '*' && strTestOnly != 'mergeContactsDifferentHHAccount') return;
        
        // this creates 2 Household Accounts, each with 2 Contacts, and a default Address for each HH
        ADDR_Addresses_TEST.createHHTestData(2, 2);
        
        // create an opp for each contact
        list<Opportunity> listOpp = UTIL_UnitTestData_TEST.OppsForContactList(ADDR_Addresses_TEST.listConT, null, 
            UTIL_UnitTestData_TEST.getclosedWonStage(), system.Today(), 100, null, null);
        insert listOpp;
        
        Contact conWinner = ADDR_Addresses_TEST.listConT[1];
        Contact conLoser = ADDR_Addresses_TEST.listConT[3];

        // create a primary affiliation for each contact
        npe5__Affiliations_Settings__c affiliationsSettingsForTests = UTIL_CustomSettingsFacade.getAffiliationsSettingsForTests(
            new npe5__Affiliations_Settings__c(npe5__Automatic_Affiliation_Creation_Turned_On__c = true));
        Account accOrg = new Account(Name='OrgAccount');
        insert accOrg;
        conWinner.Primary_Affiliation__c = accOrg.Id;
        conLoser.Primary_Affiliation__c = accOrg.Id;
        AFFL_Affiliations_TDTM.doNotRunForContacts = false;
        AFFL_Affiliations_TDTM.hasRunForAccounts = false;
        AFFL_Affiliations_TDTM.hasRunForAffiliations = false;
        update new list<Contact> {conWinner, conLoser};        
        AFFL_Affiliations_TDTM.doNotRunForContacts = false;
        AFFL_Affiliations_TDTM.hasRunForAccounts = false;
        AFFL_Affiliations_TDTM.hasRunForAffiliations = false;
        system.assertEquals(2, [select count() from npe5__Affiliation__c]);              

        Test.startTest();
        merge conWinner conLoser;

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our accounts
        list<Account> listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, 
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account where Name <> 'OrgAccount' order by Id]);
        system.assertEquals(conWinner.AccountId, listAcc[0].Id);
        Account accWinner = listAcc[0];
        system.assertEquals(conLoser.AccountId, listAcc[1].Id);
        Account accLoser = listAcc[1];

        // reload our contacts
        list<Contact> listCon = [select Id, Firstname, AccountId, npo02__NumberOfClosedOpps__c,
            is_Address_Override__c, Current_Address__c, Current_Address__r.Household_Account__c,
            MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Firstname];
        system.assertEquals(conWinner.Id, listCon[1].Id);
        conWinner = listCon[1];            
            
        // verify the merge
        system.assertEquals(2, listAcc.size());
        system.assertEquals(3, listCon.size());
        system.assertEquals(2, [select count() from Contact where AccountId = :conWinner.AccountId]);
        system.assertEquals(1, [select count() from Contact where AccountId = :conLoser.AccountId]);
                    
        // verify the account's names and greetings are updated
        system.assertEquals(true, accWinner.npo02__Formal_Greeting__c.contains(conWinner.Firstname));    
        system.assertEquals(false, accWinner.npo02__Formal_Greeting__c.contains(conLoser.Firstname));        
        system.assertEquals(false, accLoser.npo02__Formal_Greeting__c.contains(conLoser.Firstname));        
        system.assertEquals(false, accLoser.npo02__Formal_Greeting__c.contains(conWinner.Firstname));    
        
        // verify opps in the correct accounts
        system.assertEquals(3, [select count() from Opportunity where AccountId = :conWinner.AccountId]);  
        system.assertEquals(1, [select count() from Opportunity where AccountId = :conLoser.AccountId]);  
            
        // verify Account rollups are still valid
        system.assertEquals(3, accWinner.npo02__NumberOfClosedOpps__c);            
        system.assertEquals(1, accLoser.npo02__NumberOfClosedOpps__c);    
        
        // verify Contact rollups are valid
        system.assertEquals(2, conWinner.npo02__NumberOfClosedOpps__c);          

        // verify Soft Credits recalculated
        system.assertEquals(3, [select count() from OpportunityContactRole where ContactId = :conWinner.Id]);        
        system.assertEquals(4, [select count() from OpportunityContactRole where isPrimary = true]);        
        system.assertEquals(7, [select count() from OpportunityContactRole]);  
        
        // verify Winner's address matches their account
        system.assertEquals(false, conWinner.is_Address_Override__c);
        system.assertEquals(conWinner.Current_Address__r.Household_Account__c, accWinner.Id);
        system.assertEquals(conWinner.MailingStreet, accWinner.BillingStreet);      

        // verify no duplicate Affiliations and one primary Affiliation
        system.assertEquals(1, [select count() from npe5__Affiliation__c where npe5__Primary__c = true]);              
        system.assertEquals(1, [select count() from npe5__Affiliation__c]);              
    }

    /*******************************************************************************************************
    * @description merge three Contacts from different Household Accounts with many affiliations.  
    * verify: 
    *   No Duplicate and Primary Affiliations
    */
    static testMethod void mergeContactsDifferentHHAccountManyAffl() {
        if (strTestOnly != '*' && strTestOnly != 'mergeContactsDifferentHHAccountManyAffl') return;
        
        // this creates 3 Household Accounts, each with 2 Contacts, and a default Address for each HH
        ADDR_Addresses_TEST.createHHTestData(3, 2);
        
        Contact conWinner = ADDR_Addresses_TEST.listConT[1];
        Contact conLoser1 = ADDR_Addresses_TEST.listConT[3];
        Contact conLoser2 = ADDR_Addresses_TEST.listConT[4];

        // create a primary affiliation for each contact
        npe5__Affiliations_Settings__c affiliationsSettingsForTests = UTIL_CustomSettingsFacade.getAffiliationsSettingsForTests(
            new npe5__Affiliations_Settings__c(npe5__Automatic_Affiliation_Creation_Turned_On__c = true));
        Account accOrg = new Account(Name='OrgAccount');
        insert accOrg;
        conWinner.Primary_Affiliation__c = accOrg.Id;
        conLoser1.Primary_Affiliation__c = accOrg.Id;
        conLoser2.Primary_Affiliation__c = accOrg.Id;
        AFFL_Affiliations_TDTM.doNotRunForContacts = false;
        AFFL_Affiliations_TDTM.hasRunForAccounts = false;
        AFFL_Affiliations_TDTM.hasRunForAffiliations = false;
        update new list<Contact> {conWinner, conLoser1, conLoser2};        
        AFFL_Affiliations_TDTM.doNotRunForContacts = false;
        AFFL_Affiliations_TDTM.hasRunForAccounts = false;
        AFFL_Affiliations_TDTM.hasRunForAffiliations = false;
        system.assertEquals(3, [select count() from npe5__Affiliation__c]);
        
        // create additional affiliations
        list<npe5__Affiliation__c> listAffl = new list<npe5__Affiliation__c>();
        listAffl.add(new npe5__Affiliation__c(npe5__Contact__c=conWinner.Id, npe5__Organization__c=accOrg.Id, npe5__Status__c='inactive'));             
        listAffl.add(new npe5__Affiliation__c(npe5__Contact__c=conLoser1.Id, npe5__Organization__c=accOrg.Id, npe5__Status__c='inactive'));             
        listAffl.add(new npe5__Affiliation__c(npe5__Contact__c=conLoser2.Id, npe5__Organization__c=accOrg.Id, npe5__Status__c='inactive'));             
        listAffl.add(new npe5__Affiliation__c(npe5__Contact__c=conLoser2.Id, npe5__Organization__c=accOrg.Id, npe5__Status__c='random'));             
        insert listAffl;
        AFFL_Affiliations_TDTM.doNotRunForContacts = false;
        AFFL_Affiliations_TDTM.hasRunForAccounts = false;
        AFFL_Affiliations_TDTM.hasRunForAffiliations = false;
        system.assertEquals(7, [select count() from npe5__Affiliation__c]);

        // now let's do the merge!
        Test.startTest();
        merge conWinner new list<Contact>{conLoser1, conLoser2};

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our contacts
        list<Contact> listCon = [select Id, Firstname, AccountId, npo02__NumberOfClosedOpps__c,
            is_Address_Override__c, Current_Address__c, Current_Address__r.Household_Account__c,
            MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Firstname];
        system.assertEquals(conWinner.Id, listCon[1].Id);
        conWinner = listCon[1];            
            
        // verify the merge
        system.assertEquals(4, listCon.size());
        system.assertEquals(2, [select count() from Contact where AccountId = :conWinner.AccountId]);
        system.assertEquals(1, [select count() from Contact where AccountId = :conLoser1.AccountId]);
        system.assertEquals(1, [select count() from Contact where AccountId = :conLoser2.AccountId]);
                    
        // verify no duplicate Affiliations and one primary Affiliation
        system.assertEquals(1, [select count() from npe5__Affiliation__c where npe5__Primary__c = true]);              
        system.assertEquals(3, [select count() from npe5__Affiliation__c]);              
    }

    /*******************************************************************************************************
    * @description Merge a Contact with an Address Override to a different Account, and verify: 
    *   the Address Override is copied to the new Account
    *   the Contact's Address Override lookup is updated
    *   the Contact's mailing address matches the override
    */
    static testMethod void mergeContactsDifferentHHAccountAddressOverride() {
        if (strTestOnly != '*' && strTestOnly != 'mergeContactsDifferentHHAccountAddressOverride') return;
        
        // this creates 2 Household Accounts, each with 2 Contacts, and a default Address for each HH
        ADDR_Addresses_TEST.createHHTestData(2, 2);
        
        Contact conWinner = ADDR_Addresses_TEST.listConT[3];
        Contact conLoser = ADDR_Addresses_TEST.listConT[0];
        
        // create their own address override
        conWinner.MailingStreet = 'street override';
        conWinner.MailingCity = 'city override';
        conWinner.is_Address_Override__c = true;
        ADDR_Addresses_TDTM.hasRunAddrTrigger = false;
        update conWinner;
        ADDR_Addresses_TDTM.hasRunAddrTrigger = false;
        
        // here we go!
        Test.startTest();
        merge conWinner conLoser;

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our accounts
        list<Account> listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account order by Id]);
        system.assertEquals(conWinner.AccountId, listAcc[1].Id);
        Account accWinner = listAcc[1];
        system.assertEquals(conLoser.AccountId, listAcc[0].Id);
        Account accLoser = listAcc[0];

        // reload our contacts
        list<Contact> listCon = [select Id, Firstname, AccountId, 
            is_Address_Override__c, Current_Address__c, Current_Address__r.Household_Account__c,
            MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Firstname];
        system.assertEquals(3, listCon.size());
        system.assertEquals(conWinner.Id, listCon[2].Id);
        conWinner = listCon[2];            
                        
        // verify the contacts belong to correct account.
        system.assertEquals(listCon[0].AccountId, accLoser.Id);
        system.assertEquals(listCon[1].AccountId, accWinner.Id);
        system.assertEquals(listCon[2].AccountId, accWinner.Id);
        
        // verify we have the expected number of addresses (2 + override we created)
        system.assertEquals(3, [select count() from Address__c]);
        system.assertEquals(2, [select count() from Address__c where Default_Address__c = true]);
        system.assertEquals(1, [select count() from Contact where is_Address_Override__c = true]);
        
        // verify the correct contact has the override
        system.assertEquals(true, conWinner.is_Address_Override__c);
        Address__c addr = [select Id, Household_Account__c, MailingStreet__c, MailingCity__c from Address__c where Id = :conWinner.Current_Address__c];
        
        // verify the address is in the winning acccount
        system.assertEquals(conWinner.AccountId, addr.Household_Account__c);
            
        // verify the contact's address is still the address override
        system.assertEquals(conWinner.MailingStreet, addr.MailingStreet__c);
        system.assertEquals(conWinner.MailingCity, addr.MailingCity__c);
    }

    /*******************************************************************************************************
    * @description merge three Contacts from different Household Accounts with many Relationships.  
    * verify: 
    *   No Duplicate Relationships
    */
    static testMethod void mergeContactsDifferentHHAccountManyRel() {
        if (strTestOnly != '*' && strTestOnly != 'mergeContactsDifferentHHAccountManyRel') return;
        
        // this creates 3 Household Accounts, each with 2 Contacts, and a default Address for each HH
        ADDR_Addresses_TEST.createHHTestData(3, 2);
        
        Contact conWinner = ADDR_Addresses_TEST.listConT[1];
        Contact conLoser1 = ADDR_Addresses_TEST.listConT[3];
        Contact conLoser2 = ADDR_Addresses_TEST.listConT[4];
        
        // create relationships between the contacts in each household
        list<npe4__Relationship__c> listRel = new list<npe4__Relationship__c>();
        for (integer i = 0; i < 3; i++) {
            npe4__Relationship__c rel = new npe4__Relationship__c(
                npe4__Contact__c = ADDR_Addresses_TEST.listConT[i * 2].id, 
                npe4__RelatedContact__c = ADDR_Addresses_TEST.listConT[i * 2 + 1].id, 
                npe4__Type__c='Friend',
                npe4__Status__c='Active',
                npe4__Description__c='notes');
            listRel.add(rel);
        }
        
        // create relationships between the winners & losers, and one of the other contacts
        // these will be the duplicate relationships that should be merged.
        Contact conRel = ADDR_Addresses_TEST.listConT[0];
        listRel.add(new npe4__Relationship__c(npe4__Contact__c=conWinner.Id, npe4__RelatedContact__c=conRel.Id));
        listRel.add(new npe4__Relationship__c(npe4__Contact__c=conLoser1.Id, npe4__RelatedContact__c=conRel.Id));
        listRel.add(new npe4__Relationship__c(npe4__Contact__c=conLoser2.Id, npe4__RelatedContact__c=conRel.Id));
        insert listRel;
        
        // verify rels all there
        system.assertEquals(12, [select count() from npe4__Relationship__c]);
        
        // now let's do the merge!
        Test.startTest();
        merge conWinner new list<Contact>{conLoser1, conLoser2};

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our contacts
        list<Contact> listCon = [select Id, Firstname, AccountId, npo02__NumberOfClosedOpps__c,
            is_Address_Override__c, Current_Address__c, Current_Address__r.Household_Account__c,
            MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Firstname];
        system.assertEquals(conWinner.Id, listCon[1].Id);
        conWinner = listCon[1];            
            
        // verify the merge
        system.assertEquals(4, listCon.size());
        system.assertEquals(2, [select count() from Contact where AccountId = :conWinner.AccountId]);
        system.assertEquals(1, [select count() from Contact where AccountId = :conLoser1.AccountId]);
        system.assertEquals(1, [select count() from Contact where AccountId = :conLoser2.AccountId]);
                    
        // verify the expected relationships
        system.assertEquals(8, [select count() from npe4__Relationship__c]);
        system.assertEquals(4, [select count() from npe4__Relationship__c where npe4__Contact__c = :conWinner.Id]);              
        system.assertEquals(4, [select count() from npe4__Relationship__c where npe4__RelatedContact__c = :conWinner.Id]);              
    }
    
    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeHHToHH() {
        if (strTestOnly != '*' && strTestOnly != 'testNamesAndOppsMergeHHToHH') return;
        testNamesAndOppsMerge(CAO_Constants.HH_ACCOUNT_TYPE, CAO_Constants.HH_ACCOUNT_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOne2OneToOne2One() {
        if (strTestOnly != '*' && strTestOnly != 'testNamesAndOppsMergeOne2OneToOne2One') return;
        testNamesAndOppsMerge(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOrgToHH() {
        if (strTestOnly != '*' && strTestOnly != 'testNamesAndOppsMergeOrgToHH') return;
        testNamesAndOppsMerge(null, CAO_Constants.HH_ACCOUNT_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeHHToOrg() {
        if (strTestOnly != '*' && strTestOnly != 'testNamesAndOppsMergeHHToOrg') return;
        testNamesAndOppsMerge(CAO_Constants.HH_ACCOUNT_TYPE, null);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOrgToOne2One() {
        if (strTestOnly != '*' && strTestOnly != 'testNamesAndOppsMergeOrgToOne2One') return;
        testNamesAndOppsMerge(null, CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOne2OneToOrg() {
        if (strTestOnly != '*' && strTestOnly != 'testNamesAndOppsMergeOne2OneToOrg') return;
        testNamesAndOppsMerge(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, null);
    }
    
    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOrgToOrg() {
        if (strTestOnly != '*' && strTestOnly != 'testNamesAndOppsMergeOrgToOrg') return;
        testNamesAndOppsMerge(null, null);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    *   the account's names and greetings are updated.
    *   Opps owned by the contact are moved over.
    *   Soft Credits for the moved Opps are recalculated.
    *   Soft Credits the contact previously had are still there.
    *   Opp Rollups are recalculated for both accounts.
    */
    static void testNamesAndOppsMerge(string accTypeLoser, string accTypeWinner) {
    
        // create our losing account and contacts
        UTIL_UnitTestData_TEST.createAccountContactTestData(accTypeLoser, 1, 2, 1);
        Account accLoser = UTIL_UnitTestData_TEST.listAccT[0];
        list<Contact> listConAll = UTIL_UnitTestData_TEST.listConT; 
        
        // create our winning account and contacts
        UTIL_UnitTestData_TEST.createAccountContactTestData(accTypeWinner, 1, 2, 3);
        Account accWinner = UTIL_UnitTestData_TEST.listAccT[0];
        listConAll.addAll(UTIL_UnitTestData_TEST.listConT);        
        
        // create an opp for each contact
        // note that for Org accounts, these Opps won't generate Soft Credits.
        list<Opportunity> listOpp = UTIL_UnitTestData_TEST.OppsForContactWithAccountList(listConAll, null, 
            UTIL_UnitTestData_TEST.getclosedWonStage(), system.Today(), 100, null, null);
        insert listOpp;
        
        // Merge the first contact in the first account to the first contact in the other account.
        Contact conWinner = listConAll[2];
        Contact conLoser = listConAll[0];
        Test.startTest();
        merge conWinner conLoser;
        Test.stopTest();

        // reload our contacts and accounts
        list<Account> listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, 
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account order by Id]);
        list<Contact> listCon = [select Id, Firstname, Lastname, AccountId, 
            is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Id];
            
        // verify the contacts belong to correct account.
        system.assertEquals(accLoser.Id, listAcc[0].Id);
        accLoser = listAcc[0];
        system.assertEquals(accWinner.Id, listAcc[1].Id);
        accWinner = listAcc[1];
        system.assertEquals(3, listCon.size());
        system.assertEquals(conWinner.Id, listCon[1].Id);
        conWinner = listCon[1];
        system.assertEquals(listCon[0].AccountId, accLoser.Id);
        system.assertEquals(conWinner.AccountId, accWinner.Id);
        system.assertEquals(listCon[2].AccountId, accWinner.Id);
            
        // verify the account's names and greetings are updated
        if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE)
            system.assertEquals(false, accLoser.npo02__Formal_Greeting__c.contains(conLoser.Firstname));        
        if (accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            system.assertEquals(false, accWinner.npo02__Formal_Greeting__c.contains(conLoser.Firstname));
            system.assertEquals(true, accWinner.npo02__Formal_Greeting__c.contains(conWinner.Firstname));
        }                
        system.assertEquals(false, accWinner.Name.contains('Anonymous'));    
        
        integer cAccLoserOpps = [select count() from Opportunity where AccountId = :accLoser.Id];
        integer cAccWinnerOpps = [select count() from Opportunity where AccountId = :accWinner.Id];
        integer cOCRCon0 = [select count() from OpportunityContactRole where ContactId = :listCon[0].Id];
        integer cOCRConWinner = [select count() from OpportunityContactRole where ContactId = :conWinner.Id];
        integer cOCRCon2 = [select count() from OpportunityContactRole where ContactId = :listCon[2].Id];
        
        // verify Opps, OCR's, and Rollups are what we expect!
        if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE && accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            system.assertEquals(1, cAccLoserOpps);
            system.assertEquals(3, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(3, cOCRConWinner);
            system.assertEquals(3, cOCRCon2);
            system.assertEquals(1, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(3, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE && accTypeWinner == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE) {
            system.assertEquals(1, cAccLoserOpps);
            system.assertEquals(3, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(1, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(3, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(3, cOCRConWinner);
            system.assertEquals(2, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE && accTypeWinner == null) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE && accTypeWinner == null) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == null) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        
    }
    
}