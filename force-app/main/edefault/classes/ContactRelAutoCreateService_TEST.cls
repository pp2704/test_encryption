/*
    Copyright (c) 2020, Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this List of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this List of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
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
* @author Salesforce.org
* @date 2020
* @group 
* @group-content ../../ApexDocContent/
* @description Test class for ContactRelAutoCreateService
*/
@isTest 
private with sharing class ContactRelAutoCreateService_TEST {

    /**************************************************************************************************************************
    * @description Test method to verify that the getInstance method returns a new instance of the 
    * ContactRelAutoCreateService class when one does not already exist.
    ***************************************************************************************************************************/
    @isTest
    private static void getInstanceNew() {
        ContactRelAutoCreateService srvcConRelAutoCreate = ContactRelAutoCreateService.getInstance();
        System.assertEquals(ContactRelAutoCreateService.instance, srvcConRelAutoCreate, 'Instance of service class returned should match static instance variable.');
        System.assertEquals(true, srvcConRelAutoCreate != null, 'Instance of service class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that the getInstance() returns the existing instance of the 
    * ContactRelAutoCreateService class when one already exists.
    ***************************************************************************************************************************/
    @isTest
    private static void getInstanceExisting() {
        ContactRelAutoCreateService srvcConRelAutoCreateInstance1 = ContactRelAutoCreateService.getInstance();
        ContactRelAutoCreateService srvcConRelAutoCreateInstance2 = ContactRelAutoCreateService.getInstance();
 
        System.assertEquals(ContactRelAutoCreateService.instance, srvcConRelAutoCreateInstance1, 'Instance of service class returned should match static instance variable.');
        System.assertEquals(srvcConRelAutoCreateInstance1, srvcConRelAutoCreateInstance2, 'Subsequent retrievals of service class instance should return existing instance.');
        System.assertEquals(true, srvcConRelAutoCreateInstance1 != null, 'Instance of service class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that the getRelationshipsToCreateForContactsTrue() returns a populated 
    * ContactsRelationshipsModel model for a list of Contact records with Relationship Auto Create mappings. 
    ***************************************************************************************************************************/
    @isTest 
    private static void getRelationshipsToCreateForContactsTrue(){
        ContactRelAutoCreateService.instance = new STUB_WithRelationshipsToCreate();

        List<Relationship_Auto_Create__c> conRelAutoCreateList = new List<Relationship_Auto_Create__c>();
        List<ContactRelAutoCreateMappingModel> conRelAutoCreateMappingList = new List<ContactRelAutoCreateMappingModel>();

        List<Contact> contactsList = UTIL_UnitTestData_TEST.getMultipleTestContacts(5);
        for (Contact con : contactsList){
            con.Id = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
        }

        for (Integer i = 0; i < 5; i++){
            Relationship_Auto_Create__c contactRelAutoCreate = new Relationship_Auto_Create__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship_Auto_Create__c.SObjectType),
                                                                                               Name = 'ConReportToAutoCreate' + i, 
                                                                                               Object__c = 'Contact',
                                                                                               Field__c = 'ReportsToId', 
                                                                                               Relationship_Type__c = 'ContactTester' + i,
                                                                                               Campaign_Types__c = '');
        
            conRelAutoCreateList.add(contactRelAutoCreate);
        }

        for (Relationship_Auto_Create__c relAutoCreate : conRelAutoCreateList){
            Schema.DescribeFieldResult conFieldDescribe = UTIL_Describe.getFieldDescribe(relAutoCreate.Object__c, relAutoCreate.Field__c);
            ContactRelAutoCreateMappingModel conRelAutoCreateMapping = new ContactRelAutoCreateMappingModel(conFieldDescribe, relAutoCreate.Relationship_Type__c, relAutoCreate.Field__c);    

            conRelAutoCreateMappingList.add(conRelAutoCreateMapping);
        }
        
        Test.startTest();
        ContactsRelationshipsModel consRelsModel = ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForContacts(contactsList, conRelAutoCreateMappingList);
        Test.stopTest();
    
        System.assertEquals(5, consRelsModel.contactIdsSet.size(), 'There should be 5 contacts with relationships to create.');
        System.assertEquals(15, consRelsModel.relatedContactIdSet.size(), 'There should be 15 related contacts associated with relationships to create.');
        System.assertEquals(15, consRelsModel.relationshipList.size(), 'There should be 15 relationships to be created.');
        System.assertEquals(5, consRelsModel.contactRelationshipsModelsByContactId.keySet().size(), 'There should be 5 ContactRelationships models associated with relationships to create.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that the getRelationshipsToCreateForContactsTrue() returns an empty ContactsRelationshipsModel
    * model for a list of Contact records without Relationship Auto Create mappings. 
    ***************************************************************************************************************************/
    @isTest 
    private static void getRelationshipsToCreateForContactsFalse(){
        ContactRelAutoCreateService.instance = new STUB_WithoutRelationshipsToCreate();

        List<Contact> contactsList = UTIL_UnitTestData_TEST.getMultipleTestContacts(5);
        for (Contact con : contactsList){
            con.Id = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
        }

        Test.startTest();
        ContactsRelationshipsModel consRelsModel = ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForContacts(contactsList, new List<ContactRelAutoCreateMappingModel>());
        Test.stopTest();

        System.assertEquals(true, consRelsModel.contactIdsSet.isEmpty(), 'There should be no contacts with relationships to create.');
        System.assertEquals(true, consRelsModel.relatedContactIdSet.isEmpty(), 'There should be no related contacts associated with relationships to create.');
        System.assertEquals(true, consRelsModel.relationshipList.isEmpty(), 'There should be no relationships to be created.');
        System.assertEquals(true, consRelsModel.contactRelationshipsModelsByContactId.keySet().isEmpty(), 'There should be no ContactRelationships models associated with relationships to create.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that the getRelationshipsToCreateForContactsTrue() returns a populated
    * ContactRelAutoCreateMappingModel model for a Contact record with Relationship Auto Create mappings. 
    ***************************************************************************************************************************/
    @isTest 
    private static void getRelationshipsToCreateForContactTrue(){
        ContactRelAutoCreateService.instance = new STUB_WithRelationshipsToCreate();
        List<ContactRelAutoCreateMappingModel> conRelAutoCreateMappingList = new List<ContactRelAutoCreateMappingModel>();
        List<Relationship_Auto_Create__c> conRelAutoCreateList = new List<Relationship_Auto_Create__c>();

        Contact con = new Contact(Id = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                  LastName = 'Testerson');

        for (Integer i = 0; i < 5; i++){
            Relationship_Auto_Create__c contactRelAutoCreate = new Relationship_Auto_Create__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship_Auto_Create__c.SObjectType),
                                                                                                Name = 'ConReportToAutoCreate' + i, 
                                                                                                Object__c = 'Contact',
                                                                                                Field__c = 'ReportsToId', 
                                                                                                Relationship_Type__c = 'ContactTester' + i,
                                                                                                Campaign_Types__c = '');
        
            conRelAutoCreateList.add(contactRelAutoCreate);
        }

        for (Relationship_Auto_Create__c relAutoCreate : conRelAutoCreateList){
            Schema.DescribeFieldResult conFieldDescribe = UTIL_Describe.getFieldDescribe(relAutoCreate.Object__c, relAutoCreate.Field__c);
            ContactRelAutoCreateMappingModel conRelAutoCreateMapping = new ContactRelAutoCreateMappingModel(conFieldDescribe, relAutoCreate.Relationship_Type__c, relAutoCreate.Field__c);    

            conRelAutoCreateMappingList.add(conRelAutoCreateMapping);
        }

        Test.startTest();
        ContactRelationshipsModel conRelationshipsModel = ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForContact(con, conRelAutoCreateMappingList);
        Test.stopTest();

        System.assertEquals(con.Id, conRelationshipsModel.contactId, 'Model should be associated with current contact record.');
        System.assertEquals(3, conRelationshipsModel.relationshipByTypeByRelatedContactId.keySet().size(), 'There should be 3 mappings for relationship type by relationship by related contact.');
        System.assertEquals(3, conRelationshipsModel.relationshipList.size(), 'There should be 3 relationships to create for current contact.');

    }

    /**************************************************************************************************************************
    * @description Test method to verify that the getRelationshipsToCreateForContactsTrue() returns an empty ContactRelationshipsModel
    * model for a Contact record without Relationship Auto Create mappings. 
    ***************************************************************************************************************************/
    @isTest 
    private static void getRelationshipsToCreateForContactFalse(){
        ContactRelAutoCreateService.instance = new STUB_WithoutRelationshipsToCreate();

        Contact con = new Contact(Id = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                  LastName = 'Testerson');

        Test.startTest();
        System.assertEquals(null, ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForContact(con, new List<ContactRelAutoCreateMappingModel>()), 'ContactRelationshipsModel should be null.');
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationshipsToCreateForUpdatedContact() returns a populated 
    * ContactRelationshipsModel model when a mapped Relationship Auto Create field on a Contact record is updated to a non null value.
    **************************************************************************************************************************/ 
    @isTest 
    private static void getRelationshipsToCreateForUpdatedContactWithNotNullChangeTrue(){
        ContactRelAutoCreateService.instance = new STUB_WithRelationshipsToCreate();

        List<Relationship_Auto_Create__c> conRelAutoCreateList = new List<Relationship_Auto_Create__c>();
        List<ContactRelAutoCreateMappingModel> conRelAutoCreateMappingList = new List<ContactRelAutoCreateMappingModel>();

        Id fakeConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

        Contact newCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType));

        Contact oldCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType));

        for (Integer i = 0; i < 5; i++){
            Relationship_Auto_Create__c contactRelAutoCreate = new Relationship_Auto_Create__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship_Auto_Create__c.SObjectType),
                                                                                                Name = 'ConReportToAutoCreate' + i, 
                                                                                                Object__c = 'Contact',
                                                                                                Field__c = 'ReportsToId', 
                                                                                                Relationship_Type__c = 'ContactTester' + i,
                                                                                                Campaign_Types__c = '');
        
            conRelAutoCreateList.add(contactRelAutoCreate);
        }

        for (Relationship_Auto_Create__c relAutoCreate : conRelAutoCreateList){
            Schema.DescribeFieldResult conFieldDescribe = UTIL_Describe.getFieldDescribe(relAutoCreate.Object__c, relAutoCreate.Field__c);
            ContactRelAutoCreateMappingModel conRelAutoCreateMapping = new ContactRelAutoCreateMappingModel(conFieldDescribe, relAutoCreate.Relationship_Type__c, relAutoCreate.Field__c);    

            conRelAutoCreateMappingList.add(conRelAutoCreateMapping);
        }

        Test.startTest();
        ContactRelationshipsModel conRelsModel = ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForUpdatedContact(newCon, oldCon, conRelAutoCreateMappingList);
        Test.stopTest();

        System.assertEquals(newCon.Id, conRelsModel.contactId, 'Contact associated with model should be current contact.');
        System.assertEquals(3, conRelsModel.relationshipByTypeByRelatedContactId.size(), 'Model should have 5 relationship by type by related contact mappings.');
        System.assertEquals(3, conRelsModel.relationshipList.size(), 'Model should have 5 relationships for contact.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationshipsToCreateForUpdatedContact() returns an empty 
    * ContactRelationshipsModel model when a mapped Relationship Auto Create field on a Contact record is updated to null.
    **************************************************************************************************************************/ 
    @isTest 
    private static void getRelationshipsToCreateForUpdatedContactWithNullChangeTrue(){
        //ContactRelAutoCreateService.instance = new STUB_WithRelationshipsToCreate();

        List<Relationship_Auto_Create__c> conRelAutoCreateList = new List<Relationship_Auto_Create__c>();
        List<ContactRelAutoCreateMappingModel> conRelAutoCreateMappingList = new List<ContactRelAutoCreateMappingModel>();

        Id fakeConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

        Contact newCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = null);

        Contact oldCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType));

        for (Integer i = 0; i < 5; i++){
            Relationship_Auto_Create__c contactRelAutoCreate = new Relationship_Auto_Create__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship_Auto_Create__c.SObjectType),
                                                                                                Name = 'ConReportToAutoCreate' + i, 
                                                                                                Object__c = 'Contact',
                                                                                                Field__c = 'ReportsToId', 
                                                                                                Relationship_Type__c = 'ContactTester' + i,
                                                                                                Campaign_Types__c = '');
        
            conRelAutoCreateList.add(contactRelAutoCreate);
        }

        for (Relationship_Auto_Create__c relAutoCreate : conRelAutoCreateList){
            Schema.DescribeFieldResult conFieldDescribe = UTIL_Describe.getFieldDescribe(relAutoCreate.Object__c, relAutoCreate.Field__c);
            ContactRelAutoCreateMappingModel conRelAutoCreateMapping = new ContactRelAutoCreateMappingModel(conFieldDescribe, relAutoCreate.Relationship_Type__c, relAutoCreate.Field__c);    
            conRelAutoCreateMappingList.add(conRelAutoCreateMapping);
        }

        Test.startTest();
        ContactRelationshipsModel conRelsModel = ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForUpdatedContact(newCon, oldCon, new List<ContactRelAutoCreateMappingModel>());
        Test.stopTest();

        System.assertEquals(newCon.Id, conRelsModel.contactId, 'Contact associated with model should be current contact.');
        System.assertEquals(true, conRelsModel.relationshipByTypeByRelatedContactId.isEmpty(), 'Model should have no relationship by type by related contact mappings.');
        System.assertEquals(true, conRelsModel.relationshipList.isEmpty(), 'Model should have no relationships for contact.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationshipsToCreateForUpdatedContact() returns an empty 
    * ContactRelationshipsModel model for an updated Contact record without a change in a mapped Relationship Auto Create field.
    **************************************************************************************************************************/ 
    @isTest 
    private static void getRelationshipsToCreateForUpdatedContactWithoutChangeTrue(){
        ContactRelAutoCreateService.instance = new STUB_WithoutRelationshipsToCreate();

        List<Relationship_Auto_Create__c> conRelAutoCreateList = new List<Relationship_Auto_Create__c>();
        List<ContactRelAutoCreateMappingModel> conRelAutoCreateMappingList = new List<ContactRelAutoCreateMappingModel>();

        Id fakeConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
        Id fakeReportsToConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

        Contact newCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = fakeReportsToConId);

        Contact oldCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = fakeReportsToConId);

        for (Integer i = 0; i < 5; i++){
            Relationship_Auto_Create__c contactRelAutoCreate = new Relationship_Auto_Create__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship_Auto_Create__c.SObjectType),
                                                                                                Name = 'ConReportToAutoCreate' + i, 
                                                                                                Object__c = 'Contact',
                                                                                                Field__c = 'ReportsToId', 
                                                                                                Relationship_Type__c = 'ContactTester' + i,
                                                                                                Campaign_Types__c = '');
        
            conRelAutoCreateList.add(contactRelAutoCreate);
        }

        for (Relationship_Auto_Create__c relAutoCreate : conRelAutoCreateList){
            Schema.DescribeFieldResult conFieldDescribe = UTIL_Describe.getFieldDescribe(relAutoCreate.Object__c, relAutoCreate.Field__c);
            ContactRelAutoCreateMappingModel conRelAutoCreateMapping = new ContactRelAutoCreateMappingModel(conFieldDescribe, relAutoCreate.Relationship_Type__c, relAutoCreate.Field__c);    

            conRelAutoCreateMappingList.add(conRelAutoCreateMapping);
        }

        Test.startTest();
        ContactRelationshipsModel conRelsModel = ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForUpdatedContact(newCon, oldCon, new List<ContactRelAutoCreateMappingModel>());
        Test.stopTest();

        System.assertEquals(newCon.Id, conRelsModel.contactId, 'Contact associated with model should be current contact.');
        System.assertEquals(true, conRelsModel.relationshipByTypeByRelatedContactId.isEmpty(), 'Model should have no relationship by type by related contact mappings.');
        System.assertEquals(true, conRelsModel.relationshipList.isEmpty(), 'Model should have no relationships for contact.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationshipsToCreateForUpdatedContact() returns an empty
    * ContactRelationshipsModel model for an updated Contact record without Relationship Auto Create mappings.
    **************************************************************************************************************************/ 
    @isTest 
    private static void getRelationshipsToCreateForUpdatedContactFalse(){
        ContactRelAutoCreateService.instance = new STUB_WithoutRelationshipsToCreate();

        Id fakeConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

        Contact newCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType));

        Contact oldCon = new Contact(Id = fakeConId,
                                     LastName = 'Testerson',
                                     ReportsToId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType));

        Test.startTest();
        ContactRelationshipsModel conRelsModel = ContactRelAutoCreateService.getInstance().getRelationshipsToCreateForUpdatedContact(newCon, oldCon, new List<ContactRelAutoCreateMappingModel>());
        Test.stopTest();

        System.assertEquals(newCon.Id, conRelsModel.contactId, 'Contact associated with model should be current contact.');
        System.assertEquals(true, conRelsModel.relationshipByTypeByRelatedContactId.isEmpty(), 'Model should have no relationship by type by related contact mappings.');
        System.assertEquals(true, conRelsModel.relationshipList.isEmpty(), 'Model should have no relationships for contact.');
    }
    
    /**************************************************************************************************************************
    * @description Test method to verify that getRelationshipsToInsertFromModel returns a list of relationships with duplicates 
    * when a ContactsRelationshipsModel model is associated with relationships and duplicates are allowed.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelationshipsToInsertFromModelTrueAllowDuplicatesTrue(){
        UTIL_CustomSettings_API.getSettingsForTests(new Hierarchy_Settings__c(Allow_AutoCreated_Duplicates__c = true));

        ContactsRelationshipsModel contactRelationshipsModel = new ContactsRelationshipsModel();
        List<ContactRelationshipsModel> conRelsModelsList = new List<ContactRelationshipsModel>();

        List<Contact> contactsList = UTIL_UnitTestData_TEST.getMultipleTestContacts(5);
        for (Contact con : contactsList){
            Id conFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
            Id relatedConFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

            con.Id = conFakeId;

            ContactRelationshipsModel conRelModel = new ContactRelationshipsModel(con.Id);

            Relationship__c motherRel1 = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                          Contact__c = conRelModel.contactId,
                                                          RelatedContact__c = relatedConFakeId,
                                                          Status__c = 'Current',
                                                          Type__c = 'Mother');

            Relationship__c motherRel2 = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                            Contact__c = conRelModel.contactId,
                                                            RelatedContact__c = relatedConFakeId,
                                                            Status__c = 'Current',
                                                            Type__c = 'Mother');

            Relationship__c motherRel3 = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                            Contact__c = conRelModel.contactId,
                                                            RelatedContact__c = relatedConFakeId,
                                                            Status__c = 'Current',
                                                            Type__c = 'Mother');

            conRelModel.addRelationship(motherRel1);
            conRelModel.addRelationship(motherRel2);
            conRelModel.addRelationship(motherRel3);

            conRelsModelsList.add(conRelModel);
        }

        for (ContactRelationshipsModel conRelsModel : conRelsModelsList){
            contactRelationshipsModel.addContactRelationshipsModel(conRelsModel);   
        }
        
        Test.startTest();
        List<Relationship__c> relationshipsList = ContactRelAutoCreateService.getInstance().getRelationshipsToInsertFromModel(contactRelationshipsModel);
        System.assertEquals(15, relationshipsList.size(), 'Each contact relationships model should be associated with 3 duplicate relationships.'); 
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationshipsToInsertFromModel returns a list of unique relationships when a
    * ContactsRelationshipsModel model is associated with relationships and duplicates are not allowed.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelationshipsToInsertFromModelTrueAllowDuplicatesFalse(){
        UTIL_CustomSettings_API.getSettingsForTests(new Hierarchy_Settings__c(Allow_AutoCreated_Duplicates__c = false));

        ContactsRelationshipsModel contactsRelationshipsModel = new ContactsRelationshipsModel();
        List<ContactRelationshipsModel> conRelsModelsList = new List<ContactRelationshipsModel>();
        List<Relationship__c> relationshipsList = new List<Relationship__c>();
        List<Relationship__c> duplicateRelationshipsList = new List<Relationship__c>();

        List<Contact> relatedContactsList = new List<Contact>();
        List<Contact> contactsList = UTIL_UnitTestData_TEST.getMultipleTestContacts(6);
        insert contactsList;

        for (Integer i = 0; i < 3; i++){
            relatedContactsList.add(contactsList[i]);
            contactsList.remove(i);
        }

        for (Integer i = 0; i < contactsList.size(); i++){
            Relationship__c motherRel1 = new Relationship__c(Contact__c = contactsList[i].Id,
                                                             RelatedContact__c = relatedContactsList[i].Id,
                                                             Status__c = 'Current',
                                                             Type__c = 'Mother');

            Relationship__c motherRel2 = new Relationship__c(Contact__c = contactsList[i].Id,
                                                             RelatedContact__c = relatedContactsList[i].Id,
                                                             Status__c = 'Current',
                                                             Type__c = 'Mother');
            duplicateRelationshipsList.add(motherRel1.clone());
            relationshipsList.add(motherRel1);
            relationshipsList.add(motherRel2);
        }

        insert relationshipsList;


        for (Relationship__c rel : duplicateRelationshipsList){
            ContactRelationshipsModel contactRelationshipsModel = new ContactRelationshipsModel(rel.Contact__c);
            contactRelationshipsModel.addRelationship(rel);
            conRelsModelsList.add(contactRelationshipsModel);

            contactsRelationshipsModel.addContactRelationshipsModel(contactRelationshipsModel);
        }
        
        Test.startTest();
        List<Relationship__c> relationshipsResultsList = ContactRelAutoCreateService.getInstance().getRelationshipsToInsertFromModel(contactsRelationshipsModel);
        Test.stopTest();

        System.assertEquals(0, relationshipsResultsList.size(), 'Duplicate relationships for each contact relationships model should be removed.'); 
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationshipsToInsertFromModel returns an empty list when an empty
    * ContactsRelationshipsModel model is specified.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelationshipsToInsertFromModelFalse(){
        ContactRelAutoCreateService.instance = new STUB_WithoutRelationshipsToCreate();

        Test.startTest();
        System.assertEquals(true, ContactRelAutoCreateService.getInstance().getRelationshipsToInsertFromModel(new ContactsRelationshipsModel()).isEmpty(), 'There should be no Relationship records to insert.');
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getDuplicateRelationship() returns False when there is no duplicate record
    * found in the list of existing Relationship records for a Contact.
    **************************************************************************************************************************/
    @isTest 
    private static void getDuplicateRelationshipFalse(){
        ContactsRelationshipsModel contactsRelationshipsModel = new ContactsRelationshipsModel();
        Contact testCon = UTIL_UnitTestData_TEST.getContact();

        Id conFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
        Id relatedConFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

        testCon.Id = conFakeId;

        ContactRelationshipsModel conRelsModel = new ContactRelationshipsModel(testCon.Id);

        Relationship__c relToCompare = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                           Contact__c = conRelsModel.contactId,
                                                           RelatedContact__c = relatedConFakeId,
                                                           Status__c = 'Current',
                                                           Type__c = 'Cousin');

        Relationship__c motherRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                        Contact__c = conRelsModel.contactId,
                                                        RelatedContact__c = relatedConFakeId,
                                                        Status__c = 'Current',
                                                        Type__c = 'Mother');

        Relationship__c sisterRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                        Contact__c = conRelsModel.contactId,
                                                        RelatedContact__c = relatedConFakeId,
                                                        Status__c = 'Current',
                                                        Type__c = 'Sister');

        conRelsModel.addRelationship(motherRel);
        conRelsModel.addRelationship(sisterRel);

        contactsRelationshipsModel.addContactRelationshipsModel(conRelsModel);   
        
        Test.startTest();
        System.assertEquals(null, ContactRelAutoCreateService.getInstance().getDuplicateRelationship(relToCompare, contactsRelationshipsModel), 'There should be no duplicate Relationship record in Contacts Relationships model.');
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getDuplicateRelationship() returns True when there is a duplicate record
    * found in the list of existing Relationship records for a Contact.
    **************************************************************************************************************************/
    @isTest 
    private static void getDuplicateRelationshipTrue(){
        ContactsRelationshipsModel contactsRelationshipsModel = new ContactsRelationshipsModel();
        Contact testCon = UTIL_UnitTestData_TEST.getContact();

        Id conFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
        Id relatedConFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

        testCon.Id = conFakeId;

        ContactRelationshipsModel conRelsModel = new ContactRelationshipsModel(testCon.Id);

        Relationship__c motherRel1 = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                        Contact__c = conRelsModel.contactId,
                                                        RelatedContact__c = relatedConFakeId,
                                                        Status__c = 'Current',
                                                        Type__c = 'Mother');

        Relationship__c motherRel2 = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                        Contact__c = conRelsModel.contactId,
                                                        RelatedContact__c = relatedConFakeId,
                                                        Status__c = 'Current',
                                                        Type__c = 'Mother');

        conRelsModel.addRelationship(motherRel1);
        conRelsModel.addRelationship(motherRel2);

        contactsRelationshipsModel.addContactRelationshipsModel(conRelsModel);   
        
        Test.startTest();
        System.assertEquals(true, ContactRelAutoCreateService.getInstance().getDuplicateRelationship(motherRel1, contactsRelationshipsModel) != null, 'There should be a duplicate Relationship record for the Contacts Relationships model.');
        Test.stopTest();
    }


    /**************************************************************************************************************************
    ****************************************************** STUBS **************************************************************
    **************************************************************************************************************************/

    /************************************************************************************************************
    * @description Stub class to simulate positive responses from getRelationshipsToCreateForContacts and 
    * getRelationshipsToCreateForContact methods in ContactRelAutoCreateService.
    *************************************************************************************************************/ 
    private class STUB_WithRelationshipsToCreate extends ContactRelAutoCreateService {
        @TestVisible
        public override ContactsRelationshipsModel getRelationshipsToCreateForContacts(List<Contact> contactsList, List<ContactRelAutoCreateMappingModel> contactRelationShipAutoCreateMapModelsList){
            
            ContactsRelationshipsModel contactsRelsModel = new ContactsRelationshipsModel();
            
            List<ContactRelationshipsModel> conRelsModelsList = new List<ContactRelationshipsModel>();            
            Map<Id, Map<String, Relationship__c>> relationshipByTypeByRelatedContactId = new Map<Id, Map<String, Relationship__c>>();
            
            for (Contact con : contactsList){
                ContactRelationshipsModel conRelsModel = new ContactRelationshipsModel(con.Id);
                conRelsModelsList.add(conRelsModel);
            }

            for (ContactRelationshipsModel contactRelationshipsModel : conRelsModelsList){ // create 3 relationships per contact 

                Relationship__c wifeRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                             Contact__c = contactRelationshipsModel.contactId,
                                                             RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                             Status__c = 'Current',
                                                             Type__c = 'Wife');

                Relationship__c motherRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                                Contact__c = contactRelationshipsModel.contactId,
                                                                RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                                Status__c = 'Current',
                                                                Type__c = 'Mother');

                Relationship__c cousinRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                                Contact__c = contactRelationshipsModel.contactId,
                                                                RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                                Status__c = 'Current',
                                                                Type__c = 'Cousin');
                
                contactRelationshipsModel.addRelationship(wifeRel);
                contactRelationshipsModel.addRelationship(motherRel);
                contactRelationshipsModel.addRelationship(cousinRel);

                contactsRelsModel.addContactRelationshipsModel(contactRelationshipsModel);
            }

            return contactsRelsModel;
            
        }
        
        @TestVisible
        public override ContactRelationshipsModel getRelationshipsToCreateForContact(Contact currentCon, List<ContactRelAutoCreateMappingModel> contactRelationShipAutoCreateMapModelsList){            

            ContactRelationshipsModel conRelationshipsModel = new ContactRelationshipsModel(currentCon.Id);

            Relationship__c wifeRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                          Contact__c = conRelationshipsModel.contactId,
                                                          RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                          Status__c = 'Current',
                                                          Type__c = 'Wife');

            Relationship__c motherRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                            Contact__c = conRelationshipsModel.contactId,
                                                            RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                            Status__c = 'Current',
                                                            Type__c = 'Mother');

            Relationship__c cousinRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                            Contact__c = conRelationshipsModel.contactId,
                                                            RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                            Status__c = 'Current',
                                                            Type__c = 'Cousin');
                
            conRelationshipsModel.addRelationship(wifeRel);
            conRelationshipsModel.addRelationship(motherRel);
            conRelationshipsModel.addRelationship(cousinRel);

            return conRelationshipsModel;
        }

        @TestVisible 
        public override ContactRelationshipsModel getRelationshipsToCreateForUpdatedContact(Contact newContact, Contact oldContact, List<ContactRelAutoCreateMappingModel> contactRelationShipAutoCreateMapModelsList){
            ContactRelationshipsModel conRelationshipsModel = new ContactRelationshipsModel(newContact.Id);

            Relationship__c wifeRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                          Contact__c = conRelationshipsModel.contactId,
                                                          RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                          Status__c = 'Current',
                                                          Type__c = 'Wife');

            Relationship__c motherRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                            Contact__c = conRelationshipsModel.contactId,
                                                            RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                            Status__c = 'Current',
                                                            Type__c = 'Mother');

            Relationship__c cousinRel = new Relationship__c(Id = UTIL_UnitTestData_TEST.getFakeId(Relationship__c.SObjectType),
                                                            Contact__c = conRelationshipsModel.contactId,
                                                            RelatedContact__c = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType),
                                                            Status__c = 'Current',
                                                            Type__c = 'Cousin');
                
            conRelationshipsModel.addRelationship(wifeRel);
            conRelationshipsModel.addRelationship(motherRel);
            conRelationshipsModel.addRelationship(cousinRel);

            return conRelationshipsModel;
        }
    }

    /************************************************************************************************************
    * @description Stub class to simulate negative responses from getRelationshipsToCreateForContacts and 
    * getRelationshipsToCreateForContact methods in ContactRelAutoCreateService.
    *************************************************************************************************************/ 
    private class STUB_WithoutRelationshipsToCreate extends ContactRelAutoCreateService {

        @TestVisible
        public override ContactsRelationshipsModel getRelationshipsToCreateForContacts(List<Contact> contactsList, List<ContactRelAutoCreateMappingModel> contactRelationShipAutoCreateMapModelsList){
            return new ContactsRelationshipsModel();
        }

        @TestVisible
        public override ContactRelationshipsModel getRelationshipsToCreateForContact(Contact contact, List<ContactRelAutoCreateMappingModel> contactRelationShipAutoCreateMapModelsList){
            return null;
        }

        @TestVisible 
        public override ContactRelationshipsModel getRelationshipsToCreateForUpdatedContact(Contact newContact, Contact oldContact, List<ContactRelAutoCreateMappingModel> contactRelationShipAutoCreateMapModelsList){
            return new ContactRelationshipsModel(newContact.Id);
        }

        @TestVisible
        public override List<Relationship__c> getRelationshipsToInsertFromModel(ContactsRelationshipsModel contactsRelationshipsModel){
            return new List<Relationship__c>();
        }
    }
}
@isTest
private with sharing class ContactRelationshipsModel_TEST {
    /**************************************************************************************************************************
    * @description Test method to verify that addRelationship() appends additional Relationship records to an existing list of 
    * records for a Contact Relationships model.
    **************************************************************************************************************************/
    @isTest 
    private static void addRelationshipWithExisting(){
        List<ContactRelationshipsModel> conRelsModelsList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);

        for (ContactRelationshipsModel conRelsMod : conRelsModelsList){
            for (Integer i = 0; i < 2; i++){
                Id relatedConFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, relatedConFakeId, 'Brother');
                conRelsMod.addRelationship(rel);
            }
        }

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : conRelsModelsList){
            for (Integer i = 0; i < 5; i++){
                Id relatedConFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, relatedConFakeId, 'Aunt');
                conRelsMod.addRelationship(rel);
            }
                    
            System.assertEquals(7, conRelsMod.relationshipList.size(), 'Contact Relationships model should have 5 new Relationship records added to existing 2 records.');
            System.assertEquals(7, conRelsMod.relationshipByTypeByRelatedContactId.keySet().size(), 'There should be 7 total related contact mappings for Contact Relationships model.');        
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that addRelationship() adds new Relationship records to an empty list of 
    * records for a Contact Relationships model.
    **************************************************************************************************************************/
    @isTest 
    private static void addRelationshipWithoutExisting(){
        List<ContactRelationshipsModel> conRelsModelsList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : conRelsModelsList){

            for (Integer i = 0; i < 5; i++){
                Id relatedConFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, relatedConFakeId, 'Aunt');
                conRelsMod.addRelationship(rel);
            }
                    
            System.assertEquals(5, conRelsMod.relationshipList.size(), 'Contact Relationships model should be associated with 5 new Relationship records.');
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelatedContactIdSet() returns a set of related Contact Ids when they exist for
    * a Contact Relationships model.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelatedContactIdSetTrue(){
        List<ContactRelationshipsModel> contactRelationshipsModelList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);

        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            List<Id> relatedContactIdsList;

            for (Integer i = 0; i < 5; i++){
                Id fakeRelConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, fakeRelConId, 'Cousin');
                conRelsMod.addRelationship(rel);
            }
        }

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            System.assertEquals(5, conRelsMod.getRelatedContactIdSet().size(), 'There should be 5 related Contact Ids associated with the current Contact Relationships model.');
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelatedContactIdSet() returns an empty set of related Contact Ids when they 
    * do not exist for a Contact Relationships model.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelatedContactIdSetFalse(){
        List<ContactRelationshipsModel> contactRelationshipsModelList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            System.assertEquals(true, conRelsMod.getRelatedContactIdSet().isEmpty(), 'There should be no related Contact Ids associated with the current Contact Relationships model.');
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationship() returns a Relationship when a matching record of a specified
    * Type is associated with a related Contact record.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelationshipTrue(){
        List<ContactRelationshipsModel> contactRelationshipsModelList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);
        Map<Id, List<Id>> relatedContactIdsListByContactId = new Map<Id, List<Id>>();

        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            List<Id> relatedContactIdsList;

            for (Integer i = 0; i < 5; i++){
                Id fakeRelConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, fakeRelConId, 'Cousin');
                conRelsMod.addRelationship(rel);

                relatedContactIdsList = relatedContactIdsListByContactId.get(conRelsMod.contactId);

                if (relatedContactIdsList == null){
                    relatedContactIdsList = new List<Id>();
                }

                relatedContactIdsList.add(fakeRelConId);
                relatedContactIdsListByContactId.put(conRelsMod.contactId, relatedContactIdsList);
            }
        }

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            List<Id> relatedContactIdsList = relatedContactIdsListByContactId.get(conRelsMod.contactId);
            for (Id relConId : relatedContactIdsList){
                System.assertEquals(true, conRelsMod.getRelationship(relConId, 'Cousin') != null, 'There should be relationships of type \'Cousin\' associated with the current related Contact.');

            }
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationship() returns null when a related Contact is not associated with 
    * Relationship records of a specified type.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelationshipFalse(){
        List<ContactRelationshipsModel> contactRelationshipsModelList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);
        Map<Id, List<Id>> relatedContactIdsListByContactId = new Map<Id, List<Id>>();

        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            List<Id> relatedContactIdsList;

            for (Integer i = 0; i < 5; i++){
                Id fakeRelConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);

                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, fakeRelConId, 'Brother');
                conRelsMod.addRelationship(rel);

                relatedContactIdsList = relatedContactIdsListByContactId.get(conRelsMod.contactId);

                if (relatedContactIdsList == null){
                    relatedContactIdsList = new List<Id>();
                }

                relatedContactIdsList.add(fakeRelConId);
                relatedContactIdsListByContactId.put(conRelsMod.contactId, relatedContactIdsList);
            }
        }

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            List<Id> relatedContactIdsList = relatedContactIdsListByContactId.get(conRelsMod.contactId);
            for (Id relConId : relatedContactIdsList){
                System.assertEquals(true, conRelsMod.getRelationship(relConId, 'Cousin') == null, 'There should be no relationships of type \'Cousin\' associated with the current related Contact.');
            }
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that getRelationship() returns null when a related Contact is not associated with any
    * Relationship records of any type.
    **************************************************************************************************************************/
    @isTest 
    private static void getRelationshipNull(){
        List<ContactRelationshipsModel> contactRelationshipsModelList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);
        Map<Id, List<Id>> relatedContactIdsListByContactId = new Map<Id, List<Id>>();

        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            List<Id> relatedContactIdsList;

            for (Integer i = 0; i < 5; i++){
                Id fakeRelConId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, fakeRelConId, 'Cousin');
                conRelsMod.addRelationship(rel);

                relatedContactIdsList = relatedContactIdsListByContactId.get(conRelsMod.contactId);

                if (relatedContactIdsList == null){
                    relatedContactIdsList = new List<Id>();
                }

                relatedContactIdsList.add(fakeRelConId);
                relatedContactIdsListByContactId.put(conRelsMod.contactId, relatedContactIdsList);
            }
        }

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            System.assertEquals(null, conRelsMod.getRelationship(UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType), 'Cousin'), 'There should be no relationships of any type associated with the current related Contact.');
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that isEmpty() returns false when a Contact Relationships model is associated with
    * Relationships records.
    **************************************************************************************************************************/
    @isTest 
    private static void isEmptyFalse(){
        List<ContactRelationshipsModel> contactRelationshipsModelList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);

        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            for (Integer i = 0; i < 5; i++){
                Relationship__c rel = UTIL_UnitTestData_TEST.getRelationship(conRelsMod.contactId, UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType), 'Cousin');
                conRelsMod.addRelationship(rel);
            }
        }

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            System.assertEquals(false, conRelsMod.isEmpty(), 'There should be relationships associated with the current Contact Relationships model.');
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Test method to verify that isEmpty() returns true when a Contact Relationships model is not associated with
    * any Relationships records.
    **************************************************************************************************************************/
    @isTest 
    private static void isEmptyTrue(){
        List<ContactRelationshipsModel> contactRelationshipsModelList = ContactRelationshipsModel_TEST.getContactRelationshipsModelList(5);

        Test.startTest();
        for (ContactRelationshipsModel conRelsMod : contactRelationshipsModelList){
            System.assertEquals(true, conRelsMod.isEmpty(), 'There should be no relationships associated with the current Contact Relationships model.');
        }
        Test.stopTest();
    }

    /**************************************************************************************************************************
    * @description Helper method to generate a list of Contact Relationships models.
    * @param contactsCount The number of Contacts to associate with Contact Relationships models.
    * @return A list of ContactRelationshipsModel.
    **************************************************************************************************************************/ 
    private static List<ContactRelationshipsModel> getContactRelationshipsModelList(Integer contactsCount){
        List<ContactRelationshipsModel> conRelsModelsList = new List<ContactRelationshipsModel>();
        List<Contact> contactsList = UTIL_UnitTestData_TEST.getMultipleTestContacts(contactsCount);
        
        for (Contact con : contactsList){
            Id conFakeId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
            con.Id = conFakeId;

            ContactRelationshipsModel conRelsModel = new ContactRelationshipsModel(conFakeId);
            conRelsModelsList.add(conRelsModel);
        }

        return conRelsModelsList;
    }
}
@isTest
private class CourseConSettingHealthCheckVMapper_TEST {

    /***************************************************************************
    *******************************INSTANCE*************************************
    ***************************************************************************/

    /***************************************************************************
    * @description Test method to verify that the getInstance method returns a
    * new instance of the CourseConSettingHealthCheckVMapper class when one does
    * not already exist.
    ***************************************************************************/
    @isTest
    private static void getInstanceNew() {

        Test.startTest();
        CourseConSettingHealthCheckVMapper courseConSettingHealthCheckVMapperInstance =
            CourseConSettingHealthCheckVMapper.getInstance();
        Test.stopTest();

        System.assertNotEquals(
            null,
            courseConSettingHealthCheckVMapperInstance,
            'Instance of view model mapper class should not be null.'
        );

        System.assertEquals(
            CourseConSettingHealthCheckVMapper.instance,
            courseConSettingHealthCheckVMapperInstance,
            'Instance of view model mapper class returned should match static instance variable.'
        );
    }

    /***************************************************************************
    * @description Test method to verify that the getInstance method returns the
    * existing instance of the CourseConSettingHealthCheckVMapper class when one
    * already exists.
    ***************************************************************************/
    @isTest
    private static void getInstanceExisting() {
        CourseConSettingHealthCheckVMapper expectedCourseConSettingHealthCheckVMapperInstance =
            CourseConSettingHealthCheckVMapper.getInstance();

        Test.startTest();
            CourseConSettingHealthCheckVMapper courseConHealthCheckVMapperInstance =
                CourseConSettingHealthCheckVMapper.getInstance();
        Test.stopTest();

        System.assertEquals(
            expectedCourseConSettingHealthCheckVMapperInstance,
            courseConHealthCheckVMapperInstance,
            'Instance of mapper class returned should match cached value.'
        );
    }

    /***************************************************************************
    ************************ HEALTH CHECK GROUP ********************************
    ***************************************************************************/

    /***************************************************************************
    * @description Test method to verify that getHealthCheckGroup handles all
    * passed health checks
    ***************************************************************************/
    @isTest
    private static void getHealthCheckGroupAllPassed() {

        CourseConnectionSettingsService.instance = 
            new STUB_CourseConnectionSettingsService_Enabled();

        RecordTypeService.instance =
            new STUB_RecordTypeServiceAll();

        CourseConSettingHealthCheckVMapper courseConHealthCheckVMapperInstance =
            CourseConSettingHealthCheckVMapper.getInstance();
 
        Test.startTest();
            HealthCheckGroupVModel healthChkVModel = courseConHealthCheckVMapperInstance.getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHCCourseConnectionsTitle,
            healthChkVModel.label,
            'Label of returned health check should match expected custom label.'
        );
        System.assertEquals(
            Label.stgHealthCheckStatusPassed,
            healthChkVModel.status,
            'Status of returned health check should match expected custom label.'
        );
        System.assertEquals(
            3,
            healthChkVModel.passedChecks,
            'Number of passed checks of returned health check should be 3.'
        );
        System.assertEquals(
            3,
            healthChkVModel.totalChecks,
            'Number of total checks of returned health check should be 3.'
        );
        System.assertEquals(
            0,
            healthChkVModel.expandedRowsList.size(),
            'No health checks should fail, making expanded rows list size 0.'
        );
        System.assertEquals(
            3,
            healthChkVModel.healthCheckItemList.size(),
            'Number of health check items of returned health check should be 3.'
        );
    }

    /***************************************************************************
    * @description Test method to verify that getHealthCheckGroup handles all
    * failed health checks when Course Connection is enabled
    ***************************************************************************/
    @isTest
    private static void getHealthCheckGroupAllFailedWhenCourseConnEnabled() {

        CourseConnectionSettingsService.instance = 
            new STUB_CourseConnectionSettingsService_EnabledWithSameIds();

        RecordTypeService.instance =
            new STUB_RecordTypeServiceAll();

        CourseConSettingHealthCheckVMapper courseConHealthCheckVMapperInstance =
            CourseConSettingHealthCheckVMapper.getInstance();
 
        Test.startTest();
            HealthCheckGroupVModel healthChkVModel = courseConHealthCheckVMapperInstance.getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHCCourseConnectionsTitle,
            healthChkVModel.label,
            'Label of returned health check should match expected custom label.'
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed,
            healthChkVModel.status,
            'Status of returned health check should match expected custom label.'
        );
        System.assertEquals(
            0,
            healthChkVModel.passedChecks,
            'No health check should be passed.'
        );
        System.assertEquals(
            3,
            healthChkVModel.totalChecks,
            'Number of total checks of returned health check should be 4.'
        );
        System.assertEquals(
            0,
            healthChkVModel.expandedRowsList.size(),
            'No health checks should fail, making expanded rows list size 0.'
        );
        System.assertEquals(
            3,
            healthChkVModel.healthCheckItemList.size(),
            'Number of health check items of returned health check should be 4.'
        );
    }

    /***************************************************************************
    * @description Test method to verify that getHealthCheckGroup handles only
    * one health check when Course Connection is disabled
    ***************************************************************************/
    @isTest
    private static void getHealthCheckGroupCourseConDisabled() {

        CourseConnectionSettingsService.instance = 
            new STUB_CourseConnectionSettingsService_Disabled();

        RecordTypeService.instance =
            new STUB_RecordTypeServiceAll();

        CourseConSettingHealthCheckVMapper courseConHealthCheckVMapperInstance =
            CourseConSettingHealthCheckVMapper.getInstance();
 
        Test.startTest();
            HealthCheckGroupVModel healthChkVModel = courseConHealthCheckVMapperInstance.getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHCCourseConnectionsTitle,
            healthChkVModel.label,
            'Label of returned health check should match expected custom label.'
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed,
            healthChkVModel.status,
            'Status of returned health check should match expected custom label.'
        );
        System.assertEquals(
            0,
            healthChkVModel.passedChecks,
            'No health check should be passed.'
        );
        System.assertEquals(
            1,
            healthChkVModel.totalChecks,
            'Number of total checks of returned health check should be 1 as we do not run other health checks if Course Connection is disabled.'
        );
        System.assertEquals(
            0,
            healthChkVModel.expandedRowsList.size(),
            'No health checks should fail, making expanded rows list size 0.'
        );
        System.assertEquals(
            1,
            healthChkVModel.healthCheckItemList.size(),
            'Number of health check items of returned health check should be 4.'
        );
    }

    /*************************************************************************************
    *************** combineAccountHealthCheckGroupViewModels *****************************
    *************************************************************************************/

    /**************************************************************************************************************************
    * @description Test to verify combineAccountHealthCheckGroupViewModels() returns a combined HealthCheckGroupVModel comprised of
    * the combined properties of the group view models passed as arguments.
    **************************************************************************************************************************/ 
    @isTest 
    private static void combineAccountHealthCheckGroupViewModelsValid(){

        List<HealthCheckGroupVModel> tstHlthChkGroupModelsList = new List<HealthCheckGroupVModel>();
        List<HealthCheckItemVModel> group1HlthChkItemList = new List<HealthCheckItemVModel>();

        group1HlthChkItemList.add(new HealthCheckItemVModel('Key1',
                                                            'Setting-X',
                                                            'Pass',
                                                            'PassedLabel',
                                                            'Description',
                                                            'RecommendedFix',
                                                            new List<HealthCheckItemVModel>()));
                                                            
        group1HlthChkItemList.add(new HealthCheckItemVModel('Key2',
                                                            'Setting-B',
                                                            'Pass',
                                                            'PassedLabel',
                                                            'Description',
                                                            'RecommendedFix',
                                                            new List<HealthCheckItemVModel>()));

        group1HlthChkItemList.add(new HealthCheckItemVModel('Key3',
                                                            'Setting-Y',
                                                            'Fail',
                                                            'FailedLabel',
                                                            'Description',
                                                            'RecommendedFix',
                                                            new List<HealthCheckItemVModel>()));


        tstHlthChkGroupModelsList.add(new HealthCheckGroupVModel('SubGroup1',
                                                                 'Fail',
                                                                 2,
                                                                 3,
                                                                 new List<String>(),
                                                                 group1HlthChkItemList));

        tstHlthChkGroupModelsList.add(new HealthCheckGroupVModel('SubGroup2',
                                                                 'Pass',
                                                                 1,
                                                                 1,
                                                                 new List<String>(),
                                                                 new List<HealthCheckItemVModel>()));


        Test.startTest();
            HealthCheckGroupVModel hlthChkGroupVMod = CourseConSettingHealthCheckVMapper.getInstance().combineAccountHealthCheckGroupViewModels(tstHlthChkGroupModelsList);
        Test.stopTest();

        System.assertEquals(Label.stgHCCourseConnectionsTitle, hlthChkGroupVMod.label, 'Group label should be \'' + Label.stgHCCourseConnectionsTitle + '\'');
        System.assertEquals(Label.stgHealthCheckStatusFailed, hlthChkGroupVMod.status, 'Group status should be \'' + Label.stgHealthCheckStatusFailed + '\'');
        System.assertEquals(3, hlthChkGroupVMod.passedChecks, 'Group passed checks should be \'' + hlthChkGroupVMod.passedChecks + '\'');
        System.assertEquals(4, hlthChkGroupVMod.totalChecks, 'Group total checks should be \'' + hlthChkGroupVMod.totalChecks + '\'');
        System.assertEquals(3, hlthChkGroupVMod.healthCheckItemList.size(), 'Group HealthCheckItems list should have \'' + hlthChkGroupVMod.healthCheckItemList.size() + '\' items');

        System.assertEquals('Setting-Y', hlthChkGroupVMod.healthCheckItemList[0].setting, 'HealthCheckItemList should be sorted alphabetically by Setting, with Failed items prioritized.');
        System.assertEquals('Setting-B', hlthChkGroupVMod.healthCheckItemList[1].setting, 'HealthCheckItemList should be sorted alphabetically by Setting, with Failed items prioritized.');
        System.assertEquals('Setting-X', hlthChkGroupVMod.healthCheckItemList[2].setting, 'HealthCheckItemList should be sorted alphabetically by Setting, with Failed items prioritized.');
    }

    /***************************************************************************
    *************** Course Connection Enable/Disable ***************************
    ***************************************************************************/

    /*********************************************************************************************
    * @description Test method to verify that getCourseConnectionsNotEnabledHealthCheckItems
    * handles all passed checks when Course Connection is enabled
    *********************************************************************************************/
    @isTest
    private static void getCourseConnectionsNotEnabledHealthCheckItemsPass() {

        CourseConnectionSettingsModel courseConnSettingsModel = new CourseConnectionSettingsModel(
            true,
            '01217000002Zs0pAAC',
            '01217000002Zs0pAAC'
        );

        Test.startTest();
            HealthCheckGroupVModel hCGroupVMdl = CourseConSettingHealthCheckVMapper.getInstance().getCourseConnectionsNotEnabledHealthCheckItems(courseConnSettingsModel);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       0,
                                                                                       0,
                                                                                       0,
                                                                                       hCGroupVMdl);

    }

    /*****************************************************************************************
    * @description Test method to verify that getCourseConnectionsNotEnabledHealthCheckItems
    * handles all failed check when Course Connection is disabled
    *****************************************************************************************/
    @isTest
    private static void getCourseConnectionsNotEnabledHealthCheckItemsFail() {

        CourseConnectionSettingsModel courseConnSettingsModel = new CourseConnectionSettingsModel(
            false,
            '01217000002Zs0pAAC',
            '01217000002Zs0pAAC'
        );

        Test.startTest();
            HealthCheckGroupVModel hCGroupVMdl = CourseConSettingHealthCheckVMapper.getInstance().getCourseConnectionsNotEnabledHealthCheckItems(courseConnSettingsModel);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hCGroupVMdl);

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgEnableCourseConnectionsTitle,
                                                                                    'Fail',
                                                                                    Label.stgHealthCheckStatusWarning,
                                                                                    Label.stgHCCourseConEnable,
                                                                                    Label.stgHCCourseConEnableFix,
                                                                                    hCGroupVMdl.healthCheckItemList); 
    }

    /***************************************************************************
    *************** Student Health Check Items ********************************
    ***************************************************************************/

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getStudentHealthCheckItemsNotAnID(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNUllModel();

        CourseConnectionSettingsModel courseConnModSettMod = 
                                            new CourseConnectionSettingsModel(true,
                                                                              '000000000000000002',
                                                                              'test');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000003',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      true);
                          
        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getStudentHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{courseConnModSettMod.studentRecordTypeId}
        );
        String expectedFix = Label.stgHCCourseConStudentNotFoundFix;
        
        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultStudentTypeTitle, 
                                                                                   'Fail', 
                                                                                   Label.stgHealthCheckStatusFailed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getStudentHealthCheckItemsIDNotInTheMap(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNUllModel();

        CourseConnectionSettingsModel courseConnModSettMod = new CourseConnectionSettingsModel(true,
                                                                                        '000000000000000002',
                                                                                        '000000000000000003');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000004',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getStudentHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{courseConnModSettMod.studentRecordTypeId}
        );
        String expectedFix = Label.stgHCCourseConStudentNotFoundFix;

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultStudentTypeTitle, 
                                                                                   'Fail', 
                                                                                   Label.stgHealthCheckStatusFailed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getStudentHealthCheckItemsNotActive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidInactive();

        CourseConnectionSettingsModel courseConnModSettMod = new CourseConnectionSettingsModel(true,
                                                                                              '000000000000000001',
                                                                                              '000000000000000002');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000001',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      false);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getStudentHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeInactive, 
            new List<Object>{rtModel.name, rtModel.developerName}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCCourseConStudentInactiveFix, 
            new List<Object>{rtModel.name, rtModel.developerName}
        );

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultStudentTypeTitle, 
                                                                                   'Fail', 
                                                                                   Label.stgHealthCheckStatusFailed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getStudentHealthCheckItems(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidActive();

        CourseConnectionSettingsModel courseConnModSettMod = new CourseConnectionSettingsModel(true,
                                                                                              '000000000000000001',
                                                                                              '000000000000000002');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000001',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getStudentHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       1,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeValid, 
            new List<Object>{rtModel.name, rtModel.developerName}
        );
        String expectedFix = Label.stgHealthCheckFixNotApplicable;

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultStudentTypeTitle, 
                                                                                   'Pass', 
                                                                                   Label.stgHealthCheckStatusPassed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /***************************************************************************
    *************** Faculty Health Check Items ********************************
    ***************************************************************************/

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getFacultyHealthCheckItemsNotAnID(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNUllModel();

        CourseConnectionSettingsModel courseConnModSettMod = new CourseConnectionSettingsModel(true,
                                                                                        '000000000000000002',
                                                                                        'test');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000003',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      true);
                          
        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getFacultyHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{courseConnModSettMod.facultyRecordTypeId}
        );
        String expectedFix = Label.stgHCCourseConFacultyNotFoundFix;
        
        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultFacultyTypeTitle, 
                                                                                   'Fail', 
                                                                                   Label.stgHealthCheckStatusFailed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getFacultyHealthCheckItemsIDNotInTheMap(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNUllModel();

        CourseConnectionSettingsModel courseConnModSettMod = new CourseConnectionSettingsModel(true,
                                                                                        '000000000000000002',
                                                                                        '000000000000000003');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000004',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getFacultyHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{courseConnModSettMod.facultyRecordTypeId}
        );
        String expectedFix = Label.stgHCCourseConFacultyNotFoundFix;

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultFacultyTypeTitle, 
                                                                                   'Fail', 
                                                                                   Label.stgHealthCheckStatusFailed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getFacultyHealthCheckItemsNotActive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidInactive();

        CourseConnectionSettingsModel courseConnModSettMod = new CourseConnectionSettingsModel(true,
                                                                                              '000000000000000001',
                                                                                              '000000000000000002');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000002',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      false);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getFacultyHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeInactive, 
            new List<Object>{rtModel.name, rtModel.developerName}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCCourseConFacultyInactiveFix, 
            new List<Object>{rtModel.name, rtModel.developerName}
        );

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultFacultyTypeTitle, 
                                                                                   'Fail', 
                                                                                   Label.stgHealthCheckStatusFailed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getFacultyHealthCheckItems(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidActive();

        CourseConnectionSettingsModel courseConnModSettMod = new CourseConnectionSettingsModel(true,
                                                                                              '000000000000000001',
                                                                                              '000000000000000002');

        RecordTypeModel rtModel = new RecordTypeModel('000000000000000002',
                                                      'Test Record Name',
                                                      'testRecordDevName',
                                                      true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{rtModel.id => rtModel};

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getFacultyHealthCheckItems(courseConnModSettMod, recordTypeModelsById);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       1,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeValid, 
            new List<Object>{rtModel.name, rtModel.developerName}
        );
        String expectedFix = Label.stgHealthCheckFixNotApplicable;

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgDefaultFacultyTypeTitle, 
                                                                                   'Pass', 
                                                                                   Label.stgHealthCheckStatusPassed, 
                                                                                   expectedDescription, 
                                                                                   expectedFix, 
                                                                                   hlthChkGroupVMod.healthCheckItemList);
    }

    /*******************************************************************************************************
    *************** getCourseConnectionRecordTypeUniquenessHealthCheckItems ********************************
    *******************************************************************************************************/

    /**************************************************************************************************************************
    * @description Test to verify getAccountRecordTypeUniquenessHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * passed when Admin and HH account record types are not the same.
    **************************************************************************************************************************/ 
    @isTest
    private static void getCourseConnectionRecordTypeUniquenessHealthCheckItemsPass(){

        CourseConnectionSettingsModel courseConnSettingsModel = new CourseConnectionSettingsModel(
            true,
            '01217000002Zs0pAAC',
            '01217000002Zs0pAAZ'
        );

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getCourseConnectionRecordTypeUniquenessHealthCheckItems(courseConnSettingsModel);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       1,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = Label.stgHCCourseConRecordTypesUniqueDesc;
        String expectedFix = Label.stgHealthCheckFixNotApplicable;

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgHCCourseConRecordTypesUnique, 
                                                                                    'Pass', 
                                                                                    Label.stgHealthCheckStatusPassed, 
                                                                                    expectedDescription, 
                                                                                    expectedFix, 
                                                                                    hlthChkGroupVMod.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getAccountRecordTypeUniquenessHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * passed when Admin and HH account record types are not the same.
    **************************************************************************************************************************/ 
    @isTest
    private static void getCourseConnectionRecordTypeUniquenessHealthCheckItemsFail(){

        CourseConnectionSettingsModel courseConnSettingsModel = new CourseConnectionSettingsModel(
            true,
            '01217000002Zs0pAAz',
            '01217000002Zs0pAAz'
        );

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVMod = 
            CourseConSettingHealthCheckVMapper.getInstance().getCourseConnectionRecordTypeUniquenessHealthCheckItems(courseConnSettingsModel);
        Test.stopTest();

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions('',
                                                                                       '',
                                                                                       0,
                                                                                       1,
                                                                                       0,
                                                                                       1,
                                                                                       hlthChkGroupVMod);

        String expectedDescription = Label.stgHCCourseConRecordTypesNotUnique;
        String expectedFix = Label.stgHCCourseConRecordTypesNotUniqueFix;

        CourseConSettingHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgHCCourseConRecordTypesUnique, 
                                                                                    'Fail', 
                                                                                    Label.stgHealthCheckStatusFailed, 
                                                                                    expectedDescription, 
                                                                                    expectedFix, 
                                                                                    hlthChkGroupVMod.healthCheckItemList);
    }

    /***************************************************************************
    *****************************  LOCATORS ************************************
    ***************************************************************************/
    
    /******************************************************************************
    * @description Test method to verify that a CourseConnectionSettingsService is
    * retrieved by the locator method.
    ******************************************************************************/
    @isTest 
    private static void locateCourseConnectionSettingsService(){

        CourseConnectionSettingsService expectedCourseConnectionSettingsService
            = CourseConnectionSettingsService.getInstance();

        CourseConSettingHealthCheckVMapper courseConHealthCheckVMapper =
            CourseConSettingHealthCheckVMapper.getInstance();

        Test.startTest();
            CourseConnectionSettingsService courseConSettingsService
                = courseConHealthCheckVMapper.locateCourseConnectionSettingsService();
        Test.stopTest();

        System.assertNotEquals(
            null,
            courseConSettingsService,
            'Instance of service class should not be null.'
        );

        System.assertEquals(
            expectedCourseConnectionSettingsService,
            courseConSettingsService,
            'Instance of service class from view model mapper should match the singleton instance.'
        );
    }

    /***************************************************************************
    * @description Test method to verify that a
    * RecordTypeService is retrieved by the locator method.
    ***************************************************************************/
    @isTest 
    private static void locateRecordTypeService(){
        RecordTypeService expectedRecordTypeService
            = RecordTypeService.getInstance();

        CourseConSettingHealthCheckVMapper courseConHealthCheckVMapper =
            CourseConSettingHealthCheckVMapper.getInstance();

        Test.startTest();
            RecordTypeService recTypeService
                = courseConHealthCheckVMapper.locateRecordTypeService();
        Test.stopTest();

        System.assertNotEquals(
            null,
            recTypeService,
            'Instance of service class should not be null.'
        );

        System.assertEquals(
            expectedRecordTypeService,
            recTypeService,
            'Instance of service class from view model mapper should match the singleton instance.'
        );
    }

    /***************************************************************************
    * @description Test method to verify that a
    * StringHandlingService is retrieved by the locator method.
    ***************************************************************************/
    @isTest 
    private static void locateStringHandlingService(){
        StringHandlingService expectedStringHandlingService
            = StringHandlingService.getInstance();

        CourseConSettingHealthCheckVMapper courseConHealthCheckVMapper =
            CourseConSettingHealthCheckVMapper.getInstance();

        Test.startTest();
            StringHandlingService stringHandlingService
                = courseConHealthCheckVMapper.locateStringHandlingService();
        Test.stopTest();

        System.assertNotEquals(
            null,
            stringHandlingService,
            'Instance of service class should not be null.'
        );

        System.assertEquals(
            expectedStringHandlingService,
            stringHandlingService,
            'Instance of service class from view model mapper should match the singleton instance.'
        );
    }

    /**************************************************************************************************************************
    ************************************************* HELPER METHODS **********************************************************
    **************************************************************************************************************************/

    /**************************************************************************************************************************
    * @description Helper method to validate assertions for HealthCheckGroupVModel tests.
    **************************************************************************************************************************/
    private static void verifyHealthCheckGroupVModelAssertions(String expectedLabel, 
                                                               String expectedStatus, 
                                                               Integer expectedPassedCheckCount, 
                                                               Integer expectedTotalCheckCount, 
                                                               Integer expectedExpandedRowSize, 
                                                               Integer expectedHealthCheckItemListSize,
                                                               HealthCheckGroupVModel hlthCheckGroupResult){

        System.assertEquals(expectedLabel, hlthCheckGroupResult.label, 'Should have \'' + expectedLabel + '\' label.');
        System.assertEquals(expectedStatus, hlthCheckGroupResult.status, 'Should have status of \'' + expectedStatus + '\'.');
        System.assertEquals(expectedPassedCheckCount, hlthCheckGroupResult.passedChecks, 'Should have ' + expectedPassedCheckCount + ' passed checks.');
        System.assertEquals(expectedTotalCheckCount, hlthCheckGroupResult.totalChecks, 'Should have ' + expectedTotalCheckCount + ' check.');
        System.assertEquals(expectedExpandedRowSize, hlthCheckGroupResult.expandedRowsList.size(), 'Should have ' + expectedExpandedRowSize + ' expanded rows.');
        System.assertEquals(expectedHealthCheckItemListSize, hlthCheckGroupResult.healthCheckItemList.size(), 'Should have ' + expectedHealthCheckItemListSize + ' health check item.');
    }

    /**************************************************************************************************************************
    * @description Helper method to validate assertions for HealthCheckGroupVModel HealthCheckItems.
    **************************************************************************************************************************/
    private static void verifyHealthCheckItemListAssertions(String expectedSetting,
                                                            String expectedStatus, 
                                                            String expectedStatusLabel,
                                                            String expectedDescription,
                                                            String expectedFix,
                                                            List<HealthCheckItemVModel> healthCheckItemList){

        for (HealthCheckItemVModel hlthChkItmVMod : healthCheckItemList){
            System.assertEquals(expectedSetting, hlthChkItmVMod.setting, 'Health Check Item setting should be \'' + expectedSetting + '\'.');
            System.assertEquals(expectedStatus, hlthChkItmVMod.status, 'Health Check Item status should be \'' + expectedStatus + '\'.');
            System.assertEquals(expectedStatusLabel, hlthChkItmVMod.statusLabel, 'Health Check Item status label should be \'' + expectedStatusLabel + '\'.');
            System.assertEquals(expectedDescription, hlthChkItmVMod.description, 'Health Check Item description should be correctly set.');
            System.assertEquals(expectedFix, hlthChkItmVMod.recommendedFix, 'Health Check Item recommended fix should be correctly set.');
        }        
    }

    /*********************************************************************************************************
    ********************************* STUB *******************************************************************
    *********************************************************************************************************/

    /*************************************************************************************************
    * @description Stub class to simulate the response from CourseConnectionSettingsService
    *  to return a predetermined a Course Connection model with Course Connection Enabled as True.
    **************************************************************************************************/
    private class STUB_CourseConnectionSettingsService_Enabled extends CourseConnectionSettingsService {

        public override CourseConnectionSettingsModel getCourseConnectionSettingsModel() {

            CourseConnectionSettingsModel courseConnSettingsModel = 
                new CourseConnectionSettingsModel(
                    true,
                    '0121A000002Zs0pAAC',
                    '0121A000002Zs0pAAB'
                );

            return courseConnSettingsModel;
        }
    }
    
    /*************************************************************************************************
    * @description Stub class to simulate the response from CourseConnectionSettingsService
    *  to return a predetermined a Course Connection model with Course Connection Enabled as False.
    **************************************************************************************************/
    private class STUB_CourseConnectionSettingsService_Disabled extends CourseConnectionSettingsService {

        public override CourseConnectionSettingsModel getCourseConnectionSettingsModel() {

            CourseConnectionSettingsModel courseConnSettingsModel = 
                new CourseConnectionSettingsModel(
                    false,
                    '000000000000000000',
                    '000000000000000000'
                );

            return courseConnSettingsModel;
        }
    }
    
    /*************************************************************************************************
    * @description Stub class to simulate the response from CourseConnectionSettingsService
    *  to return a predetermined a Course Connection model with Course Connection Enabled as True.
    **************************************************************************************************/
    private class STUB_CourseConnectionSettingsService_EnabledWithSameIds extends CourseConnectionSettingsService {

        public override CourseConnectionSettingsModel getCourseConnectionSettingsModel() {

            CourseConnectionSettingsModel courseConnSettingsModel = 
                new CourseConnectionSettingsModel(
                    true,
                    '000000000000000000',
                    '000000000000000000'
                );

            return courseConnSettingsModel;
        }
    }

    /****************************************************************************
    * @description Stub class to simulate the response from
    * RecordTypeService to return a predetermined map of Id to Record type models
    *****************************************************************************/
    private class STUB_RecordTypeServiceAll extends RecordTypeService {

        public override  Map<Id, RecordTypeModel> getModelByIdMapForSObjectType(Schema.SObjectType sObjectType) {

            RecordTypeModel recTypeModel1 = 
                new RecordTypeModel(
                    '01217000002Zs0pAAC',
                    'test1 name',
                    'test1 dev name',
                    true
                );

            RecordTypeModel recTypeModel2 = 
                new RecordTypeModel(
                    '01217000002Zs0pAAB',
                    'test2 name',
                    'test2 dev name',
                    true
                );

            Map<Id, RecordTypeModel> recTypemodelByID = new Map<Id, RecordTypeModel>{'0121A000002Zs0pAAC' => recTypeModel1, 
                                                                                     '0121A000002Zs0pAAB' => recTypeModel2};

            return recTypemodelByID;
        }
    }

    /****************************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return a valid and active RecordTypeModel from getRecordTypeModelFromMap.
    *****************************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceNUllModel extends RecordTypeService {
        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            return null;
        }
    }

    /****************************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return a valid and active RecordTypeModel from getRecordTypeModelFromMap.
    ****************************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceValidInactive extends RecordTypeService {
        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            RecordTypeModel rtModel = new RecordTypeModel('000000000000000002',
                                                          'Test Record Name',
                                                          'testRecordDevName',
                                                          false);
            return rtModel;
        }
    }

    /****************************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return a valid and active RecordTypeModel from getRecordTypeModelFromMap.
    ****************************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceValidActive extends RecordTypeService {
        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            RecordTypeModel rtModel = new RecordTypeModel('000000000000000002',
                                                          'Test Record Name',
                                                          'testRecordDevName',
                                                          true);
            return rtModel;
        }
    }
}
/*
    Copyright (c) 2021, Salesforce.org
    All rights reserved.
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
    notice, this List of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this List of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
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
 * @author Salesforce.org
 * @date 2021
 * @group
 * @group-content ../../ApexDocContent/Tests
 * @description Test class for ErrorSettingsVMapper
 */
@isTest
private with sharing class ErrorSettingsVMapper_TEST {
    private static Integer loopCounter = 5;

    /**************************************************************************************************************************
     * @description Test method to verify that the getInstance method returns a new instance of the
     * ErrorSettingsVMapper class when one does not already exist.
     ***************************************************************************************************************************/
    @isTest
    private static void getInstanceNew() {
        Test.startTest();
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();
        Test.stopTest();

        System.assertEquals(
            ErrorSettingsVMapper.instance,
            errorSettingsVMapperInstance,
            'Instance of service class returned should match static instance variable.'
        );

        System.assertEquals(
            true,
            errorSettingsVMapperInstance != null,
            'Instance of service class should not be null.'
        );
    }

    /**************************************************************************************************************************
     * @description Test method to verify that the getInstance method returns the existing instance of the
     * ErrorSettingsVMapper class when one already exists.
     ***************************************************************************************************************************/
    @isTest
    private static void getInstanceExisting() {
        Test.startTest();
        ErrorSettingsVMapper errorSettingsVMapperInstance1 = ErrorSettingsVMapper.getInstance();
        ErrorSettingsVMapper errorSettingsVMapperInstance2 = ErrorSettingsVMapper.getInstance();
        Test.stopTest();

        System.assertEquals(
            ErrorSettingsVMapper.instance,
            errorSettingsVMapperInstance1,
            'Instance of service class returned should match static instance variable.'
        );

        System.assertEquals(
            errorSettingsVMapperInstance1,
            errorSettingsVMapperInstance2,
            'Subsequent retrievals of service class instance should return existing instance.'
        );

        System.assertEquals(
            true,
            errorSettingsVMapperInstance1 != null,
            'Instance of service class should not be null.'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the locateErrorSettingsService method returns instance of ErrorSettingsService
     ***********************************************************************************************************************************/
    @isTest
    private static void locateErrorSettingsServiceValid() {
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        ErrorSettingsService errorSettingsServiceInstance = errorSettingsVMapperInstance.locateErrorSettingsService();
        Test.stopTest();

        System.assertEquals(
            ErrorSettingsService.getInstance(),
            errorSettingsServiceInstance,
            'Should return the instance of ErrorSettingsService'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the locateUserService method returns instance of UserService
     ***********************************************************************************************************************************/
    @isTest
    private static void locateUserServiceValid() {
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        UserService userServiceInstance = errorSettingsVMapperInstance.locateUserService();
        Test.stopTest();

        System.assertEquals(
            UserService.getInstance(),
            userServiceInstance,
            'Should return the instance of UserService'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the locateUserLookupResultVMapper method returns instance of UserLookupResultVMapper
     ***********************************************************************************************************************************/
    @isTest
    private static void locateUserLookupResultVMapperValid() {
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        UserLookupResultVMapper userLookupResultVMapperInstance = errorSettingsVMapperInstance.locateUserLookupResultVMapper();
        Test.stopTest();

        System.assertEquals(
            UserLookupResultVMapper.getInstance(),
            userLookupResultVMapperInstance,
            'Should return the instance of UserLookupResultVMapper'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getErrorSettingsViewModel method returns an ErrorSettingsVModel that reflects the
     * error settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getErrorSettingsViewModelValid() {
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceAllSysAdmins();
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        ErrorSettingsVModel errorSettingsVModel = errorSettingsVMapperInstance.getErrorSettingsViewModel();
        Test.stopTest();

        System.assertEquals(
            true,
            errorSettingsVModel.storeErrors,
            'Store errors functionality should match expected value.'
        );

        System.assertEquals(
            true,
            errorSettingsVModel.sendErrorNotifications,
            'Send error notifications functionality should match expected value.'
        );

        System.assertEquals(
            'All Sys Admins',
            errorSettingsVModel.errorNotificationsRecipientCategory.value,
            'Send Error Notificiation recipient category should match expected value.'
        );
        System.assertEquals(
            1,
            errorSettingsVModel.errorNotificationsRecipientCategory.options.size(),
            'Number of Send Error Notificiation recipient category valid options should match expected size.'
        );
        System.assertEquals(
            'All Sys Admins',
            errorSettingsVModel.errorNotificationsRecipientCategory.options[0].value,
            'Send Error Notificiation recipient category valid option for All Sys Admins should have expected value.'
        );
        System.assertEquals(
            'All Sys Admins Label',
            errorSettingsVModel.errorNotificationsRecipientCategory.options[0].label,
            'Send Error Notificiation recipient category valid option for All Sys Admins should have expected label.'
        );

        System.assertEquals(
            null,
            errorSettingsVModel.userOrChatterGroupLookupResult,
            'Send Error Notification recipient lookup should be null.'
        );

        System.assertEquals(
            false,
            errorSettingsVModel.enableDebug,
            'Enable debug functionality should match expected value.'
        );

        System.assertEquals(
            true,
            errorSettingsVModel.errorHandling,
            'Error handling model property should match expected value.'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getErrorSettingsViewModel method returns an ErrorSettingsVModel that reflects the
     * error settings set in hierarchy settings for user notification sending
     ***********************************************************************************************************************************/
    @isTest
    private static void getErrorSettingsViewModelUser() {
        Id userId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceUser(userId);
        UserService.instance = new STUB_UserService(userId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        ErrorSettingsVModel errorSettingsVModel = errorSettingsVMapperInstance.getErrorSettingsViewModel();
        Test.stopTest();

        System.assertEquals(
            true,
            errorSettingsVModel.storeErrors,
            'Store errors functionality should match expected value.'
        );

        System.assertEquals(
            true,
            errorSettingsVModel.sendErrorNotifications,
            'Send error notifications functionality should match expected value.'
        );

        System.assertEquals(
            'User',
            errorSettingsVModel.errorNotificationsRecipientCategory.value,
            'Send Error Notificiation recipient category should match expected value.'
        );
        System.assertEquals(
            1,
            errorSettingsVModel.errorNotificationsRecipientCategory.options.size(),
            'Number of Send Error Notificiation recipient category valid options should match expected size.'
        );
        System.assertEquals(
            'User',
            errorSettingsVModel.errorNotificationsRecipientCategory.options[0].value,
            'Send Error Notificiation recipient category valid option for User should have expected value.'
        );
        System.assertEquals(
            'User Label',
            errorSettingsVModel.errorNotificationsRecipientCategory.options[0].label,
            'Send Error Notificiation recipient category valid option for User should have expected label.'
        );

        ErrorSettingsVMapper_TEST.assertUserLookupResult(errorSettingsVModel.userOrChatterGroupLookupResult, userId);

        System.assertEquals(
            false,
            errorSettingsVModel.enableDebug,
            'Enable debug functionality should match expected value.'
        );

        System.assertEquals(
            true,
            errorSettingsVModel.errorHandling,
            'Error handling model property should match expected value.'
        );
    }

    /**
     * @description Helper method to assert user lookup results for user service stub
     */
    private static void assertUserLookupResult(LookupResult lookupResult, String userId) {
        System.assertNotEquals(null, lookupResult, 'Lookup Result should not be null.');
        System.assertEquals(
            'User Name',
            lookupResult.label,
            'Send Error Notification recipient lookup label should be the expected label.'
        );
        System.assertEquals(
            userId,
            lookupResult.value,
            'Send Error Notification recipient lookup value should be the expected value.'
        );
        System.assertEquals(
            'standard:avatar',
            lookupResult.icon,
            'Send Error Notification recipient lookup icon should be the expected icon.'
        );
        System.assertEquals(
            'User SObject Label',
            lookupResult.alternativeText,
            'Send Error Notification recipient lookup alternative text should be the expected value.'
        );
        System.assertEquals(
            'https://example.com/user.png',
            lookupResult.imageUrl,
            'Send Error Notification recipient lookup image url should be the expected value.'
        );
        System.assertEquals(
            'user@test.com',
            lookupResult.meta,
            'Send Error Notification recipient lookup meta should be the expected value.'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getErrorSettingsViewModel method returns an ErrorSettingsVModel that reflects the
     * error settings set in hierarchy settings for user notification sending
     ***********************************************************************************************************************************/
    @isTest
    private static void getErrorSettingsViewModelChatterGroup() {
        Id chatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceChatterGroup(chatterGroupId);
        ChatterGroupService.instance = new STUB_ChatterGroupService(chatterGroupId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        ErrorSettingsVModel errorSettingsVModel = errorSettingsVMapperInstance.getErrorSettingsViewModel();
        Test.stopTest();

        System.assertEquals(
            true,
            errorSettingsVModel.storeErrors,
            'Store errors functionality should match expected value.'
        );

        System.assertEquals(
            true,
            errorSettingsVModel.sendErrorNotifications,
            'Send error notifications functionality should match expected value.'
        );

        System.assertEquals(
            'Chatter Group',
            errorSettingsVModel.errorNotificationsRecipientCategory.value,
            'Send Error Notificiation recipient category should match expected value.'
        );
        System.assertEquals(
            1,
            errorSettingsVModel.errorNotificationsRecipientCategory.options.size(),
            'Number of Send Error Notificiation recipient category valid options should match expected size.'
        );
        System.assertEquals(
            'Chatter Group',
            errorSettingsVModel.errorNotificationsRecipientCategory.options[0].value,
            'Send Error Notificiation recipient category valid option for User should have expected value.'
        );
        System.assertEquals(
            'Chatter Group Label',
            errorSettingsVModel.errorNotificationsRecipientCategory.options[0].label,
            'Send Error Notificiation recipient category valid option for User should have expected label.'
        );

        ErrorSettingsVMapper_TEST.assertChatterGroupLookupResult(
            errorSettingsVModel.userOrChatterGroupLookupResult,
            chatterGroupId
        );

        System.assertEquals(
            false,
            errorSettingsVModel.enableDebug,
            'Enable debug functionality should match expected value.'
        );

        System.assertEquals(
            true,
            errorSettingsVModel.errorHandling,
            'Error handling model property should match expected value.'
        );
    }

    /**
     * @description Helper method to assert chatter group lookup results for chatter group service stub
     */
    private static void assertChatterGroupLookupResult(LookupResult lookupResult, String chatterGroupId) {
        System.assertNotEquals(null, lookupResult, 'Lookup Result should not be null.');
        System.assertEquals(
            'Chatter Group Name',
            lookupResult.label,
            'Send Error Notification recipient lookup label should be the expected label.'
        );
        System.assertEquals(
            chatterGroupId,
            lookupResult.value,
            'Send Error Notification recipient lookup value should be the expected value.'
        );
        System.assertEquals(
            'standard:groups',
            lookupResult.icon,
            'Send Error Notification recipient lookup icon should be the expected icon.'
        );
        System.assertEquals(
            Label.stgOptChatterGroup,
            lookupResult.alternativeText,
            'Send Error Notification recipient lookup alternative text should be the expected value.'
        );
        System.assertEquals(
            'https://fake.url/test.png',
            lookupResult.imageUrl,
            'Send Error Notification recipient lookup image url should be the expected value.'
        );
        System.assertEquals(
            'Chatter Group Description',
            lookupResult.meta,
            'Send Error Notification recipient lookup meta should be the expected value.'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getErrorSettingsViewModelValid method returns a ComboboxVModel that reflects the
     * error settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getErrorNotificationsRecipientCategoryVModel() {
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceAllSysAdmins();

        ErrorSettingsModel errorSettingsModel = ErrorSettingsService.getInstance().getErrorSettingsModel();

        Test.startTest();
        ComboboxVModel comboboxVModel = errorSettingsVMapperInstance.getErrorNotificationsRecipientCategoryVModel(
            errorSettingsModel
        );
        Test.stopTest();

        System.assertEquals(
            'All Sys Admins',
            comboboxVModel.value,
            'Combobox View Model value should match expected value.'
        );
        System.assertEquals(
            1,
            comboboxVModel.options.size(),
            'Combobox View Model valid options should match expected size.'
        );
        System.assertEquals(
            'All Sys Admins',
            comboboxVModel.options[0].value,
            'Combobox View Model valid option for All Sys Admins should have expected value.'
        );
        System.assertEquals(
            'All Sys Admins Label',
            comboboxVModel.options[0].label,
            'Combobox View Model valid option for All Sys Admins should have expected label.'
        );
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getLookupResultForSettingAllSysAdmins() {
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getLookupResultForSetting(
            'All Sys Admins',
            'All Sys Admins'
        );
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for \'All Sys Admins\'.');
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getLookupResultForSettingInvalid() {
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getLookupResultForSetting('Bad Value', 'Bad Value');
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for invalid values.');
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getLookupResultForSettingUserValid() {
        Id userId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceUser(userId);
        UserService.instance = new STUB_UserService(userId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getLookupResultForSetting('User', userId);
        Test.stopTest();

        ErrorSettingsVMapper_TEST.assertUserLookupResult(lookupResult, userId);
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getLookupResultForSettingUserInvalidId() {
        Id userId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        Id unfoundUserId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceUser(unfoundUserId);
        UserService.instance = new STUB_UserService(userId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getLookupResultForSetting('User', unfoundUserId);
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for an unfound user id.');
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getUserLookupResultByIdValid() {
        Id userId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceUser(userId);
        UserService.instance = new STUB_UserService(userId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getUserLookupResultById(userId);
        Test.stopTest();

        ErrorSettingsVMapper_TEST.assertUserLookupResult(lookupResult, userId);
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getUserLookupResultByIdUnfoundUserId() {
        Id userId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        Id unfoundUserId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceUser(unfoundUserId);
        UserService.instance = new STUB_UserService(userId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getUserLookupResultById(unfoundUserId);
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for an unfound user id.');
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getUserLookupResultByIdNonId() {
        Id userId = UTIL_UnitTestData_TEST.getFakeId(User.getSObjectType());
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceUser(userId);
        UserService.instance = new STUB_UserService(userId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getUserLookupResultById('Not an Id.');
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for a non-id.');
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getLookupResultForSettingChatterGroupValid() {
        Id chatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceChatterGroup(chatterGroupId);
        ChatterGroupService.instance = new STUB_ChatterGroupService(chatterGroupId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getLookupResultForSetting(
            'Chatter Group',
            chatterGroupId
        );
        Test.stopTest();

        ErrorSettingsVMapper_TEST.assertChatterGroupLookupResult(lookupResult, chatterGroupId);
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getLookupResultForSettingChatterGroupInvalidId() {
        Id chatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        Id unfoundChatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceChatterGroup(chatterGroupId);
        ChatterGroupService.instance = new STUB_ChatterGroupService(chatterGroupId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getLookupResultForSetting(
            'Chatter Group',
            unfoundChatterGroupId
        );
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for an unfound chatter group id.');
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getChatterGroupLookupResultById method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getChatterGroupLookupResultByIdValid() {
        Id chatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceChatterGroup(chatterGroupId);
        ChatterGroupService.instance = new STUB_ChatterGroupService(chatterGroupId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getChatterGroupLookupResultById(chatterGroupId);
        Test.stopTest();

        ErrorSettingsVMapper_TEST.assertChatterGroupLookupResult(lookupResult, chatterGroupId);
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getLookupResultForSetting method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getChatterGroupLookupResultByIdUnfoundId() {
        Id chatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        Id unfoundChatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceChatterGroup(chatterGroupId);
        ChatterGroupService.instance = new STUB_ChatterGroupService(chatterGroupId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getChatterGroupLookupResultById(unfoundChatterGroupId);
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for an unfound user id.');
    }

    /***********************************************************************************************************************************
     * @description Test method to verify that the getChatterGroupLookupResultById method returns a LookupResult that reflects the error
     * settings set in hierarchy settings
     ***********************************************************************************************************************************/
    @isTest
    private static void getChatterGroupLookupResultByIdNonId() {
        Id chatterGroupId = UTIL_UnitTestData_TEST.getChatterGroupNoDependencyFakeId();
        ErrorSettingsService.instance = new STUB_ErrorSettingsServiceChatterGroup(chatterGroupId);
        ChatterGroupService.instance = new STUB_ChatterGroupService(chatterGroupId);
        ErrorSettingsVMapper errorSettingsVMapperInstance = ErrorSettingsVMapper.getInstance();

        Test.startTest();
        LookupResult lookupResult = errorSettingsVMapperInstance.getChatterGroupLookupResultById('Not an Id.');
        Test.stopTest();

        System.assertEquals(null, lookupResult, 'Lookup result should be null for a non-id.');
    }

    /**************************************************************************************************************************
     ****************************************************** STUBS **************************************************************
     **************************************************************************************************************************/

    /*********************************************************************************************************************
     * @description Stub class to simulate the response from ErrorSettingsService to return a valid ErrorSettingsModel
     *********************************************************************************************************************/
    private class STUB_ErrorSettingsServiceAllSysAdmins extends ErrorSettingsService {
        public override ErrorSettingsModel getErrorSettingsModel() {
            return new ErrorSettingsModel(true, true, 'All Sys Admins', 'All Sys Admins', false, true);
        }

        public override Map<String, String> getValidErrorNotificationRecipientCategoryLabelsByValue() {
            Map<String, String> validErrorNotificationRecipientCategoryLabelsByValue = new Map<String, String>();

            validErrorNotificationRecipientCategoryLabelsByValue.put('All Sys Admins', 'All Sys Admins Label');

            return validErrorNotificationRecipientCategoryLabelsByValue;
        }
    }

    /*********************************************************************************************************************
     * @description Stub class to simulate the response from ErrorSettingsService to return a valid ErrorSettingsModel
     *********************************************************************************************************************/
    private class STUB_ErrorSettingsServiceUser extends ErrorSettingsService {
        public String userId;

        public STUB_ErrorSettingsServiceUser(String userId) {
            this.userId = userId;
        }

        public override ErrorSettingsModel getErrorSettingsModel() {
            return new ErrorSettingsModel(true, true, 'User', this.userId, false, true);
        }

        public override Map<String, String> getValidErrorNotificationRecipientCategoryLabelsByValue() {
            Map<String, String> validErrorNotificationRecipientCategoryLabelsByValue = new Map<String, String>();

            validErrorNotificationRecipientCategoryLabelsByValue.put('User', 'User Label');

            return validErrorNotificationRecipientCategoryLabelsByValue;
        }
    }

    /*********************************************************************************************************************
     * @description Stub class to simulate the response from ErrorSettingsService to return a valid ErrorSettingsModel
     *********************************************************************************************************************/
    private class STUB_ErrorSettingsServiceChatterGroup extends ErrorSettingsService {
        public String chatterGroupId;

        public STUB_ErrorSettingsServiceChatterGroup(String chatterGroupId) {
            this.chatterGroupId = chatterGroupId;
        }

        public override ErrorSettingsModel getErrorSettingsModel() {
            return new ErrorSettingsModel(true, true, 'Chatter Group', this.chatterGroupId, false, true);
        }

        public override Map<String, String> getValidErrorNotificationRecipientCategoryLabelsByValue() {
            Map<String, String> validErrorNotificationRecipientCategoryLabelsByValue = new Map<String, String>();

            validErrorNotificationRecipientCategoryLabelsByValue.put('Chatter Group', 'Chatter Group Label');

            return validErrorNotificationRecipientCategoryLabelsByValue;
        }
    }

    /*********************************************************************************************************************
     * @description Stub class to simulate the response from ErrorSettingsService to return a valid ErrorSettingsModel
     *********************************************************************************************************************/
    private class STUB_UserService extends UserService {
        public Id userId;

        public STUB_UserService(Id userId) {
            this.userId = userId;
        }

        public override UserModel getUserModelById(Id userId) {
            if (userId != this.userId) {
                return null;
            }

            return new UserModel(
                Id.valueOf(this.userId),
                'User Name',
                true,
                'user@test.com',
                'https://example.com/user.png'
            );
        }

        public override String getModelObjectLabel() {
            return 'User SObject Label';
        }
    }

    /**
     * @description Stub class to simulate the response from ChatterGroupService
     */
    private class STUB_ChatterGroupService extends ChatterGroupService {
        private Id chatterGroupId;

        STUB_ChatterGroupService(Id chatterGroupId) {
            this.chatterGroupId = chatterGroupId;
        }

        public override ChatterGroupModel getChatterGroupModelById(Id chatterGroupId) {
            if (chatterGroupId != this.chatterGroupId) {
                return null;
            }

            return new ChatterGroupModel(
                this.chatterGroupId,
                'Chatter Group Name',
                'Chatter Group Description',
                'https://fake.url/test.png'
            );
        }

        public override List<ChatterGroupModel> getChatterGroupModelsLikeName(
            String chatterGroupNameMatch,
            Integer recordLimit
        ) {
            List<ChatterGroupModel> chatterGroupModelModelList = new List<ChatterGroupModel>();

            if ('Chatter Group Name'.toLowerCase().contains(chatterGroupNameMatch.toLowerCase())) {
                chatterGroupModelModelList.add(
                    new ChatterGroupModel(
                        this.chatterGroupId,
                        'Chatter Group Name',
                        'Chatter Group Description',
                        'https://fake.url/test.png'
                    )
                );
            }

            return chatterGroupModelModelList;
        }
    }
}
/*
    Copyright (c) 2020, Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
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
* @author Salesforce.org
* @date 2020
* @group Facility
* @group-content ../../ApexDocContent/Facility.htm
* @description Tests for FACI_CannotDelete_TDTM
*/
@isTest
private class FACI_CannotDelete_TEST {
    /*********************************************************************************************************
    * @description Retrieves the Administrative record type Id. 
    */
    public static String adminAccRecTypeId = UTIL_Describe.getAdminAccRecTypeID(); 
    
    /*********************************************************************************************************
    * @description Retrieves the Academic Program record type Id. 
    */
    public static String academicAccRecTypeId = UTIL_Describe.getAcademicAccRecTypeID(); 
    
    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is enabled in Hierarchy Settings, and
    * Facilities has a Facilities record associated to it, then it cannot be deleted.
    */
    @isTest
    public static void cannotDeleteFacilitiesWithFacilities() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = True));

        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 

        List<Facility__c> childFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c childFacility1 = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c childFacility2 = UTIL_UnitTestData_TEST.getFacility(); 
        childFacility1.Parent_Facility__c = parentFacility.Id; 
        childFacility2.Parent_Facility__c = parentFacility2.Id; 
        childFacilitiesToInsert.add(childFacility1); 
        childFacilitiesToInsert.add(childFacility2); 
        insert childFacilitiesToInsert; 

        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();

        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(2, returnParentFacilities.size());
        System.assertEquals(Label.CannotDelete, results[0].errors[0].message);  
    }
    
    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is enabled in Hierarchy Settings, and
    * Facilities has a Course Offering record associated to it, then it cannot be deleted.
    */
    @isTest
    public static void cannotDeleteFacilitiesWithCourseOffering() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = True));

        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 

        List<Account> department = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, academicAccRecTypeId);
        insert department; 
        Course__c course = new Course__c(Account__c = department[0].Id, Name = 'Bio'); 
        insert course; 
        Term__c term = UTIL_UnitTestData_TEST.getTerm(department[0].Id, 'Fall'); 
        insert term; 
        
        List<Course_Offering__c> courseOfferingsToInsert = new List<Course_Offering__c>(); 
        Course_Offering__c courseOffering1 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        Course_Offering__c courseOffering2 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        courseOffering1.Facility__c = parentFacilitiesToInsert[0].Id;
        courseOffering2.Facility__c = parentFacilitiesToInsert[1].Id;
        courseOfferingsToInsert.add(courseOffering1); 
        courseOfferingsToInsert.add(courseOffering2);
        update courseOfferingsToInsert; 

        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();

        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(2, returnParentFacilities.size());
        System.assertEquals(Label.CannotDelete, results[0].errors[0].message);  
    }
    
    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is enabled in Hierarchy Settings, and
    * Facilities has a Facilities and Course Offering record associated to it, then it cannot be deleted.
    */
    @isTest
    public static void cannotDeleteFacilitiesWithChildRecords() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = True));

        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        List<Facility__c> childFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c childFacility1 = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c childFacility2 = UTIL_UnitTestData_TEST.getFacility(); 
        childFacility1.Parent_Facility__c = parentFacility.Id; 
        childFacility2.Parent_Facility__c = parentFacility2.Id; 
        childFacilitiesToInsert.add(childFacility1); 
        childFacilitiesToInsert.add(childFacility2); 
        insert childFacilitiesToInsert; 

        List<Account> department = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, academicAccRecTypeId);
        insert department; 
        Course__c course = new Course__c(Account__c = department[0].Id, Name = 'Bio'); 
        insert course; 
        Term__c term = UTIL_UnitTestData_TEST.getTerm(department[0].Id, 'Fall'); 
        insert term; 
        
        List<Course_Offering__c> courseOfferingsToInsert = new List<Course_Offering__c>(); 
        Course_Offering__c courseOffering1 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        Course_Offering__c courseOffering2 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        courseOffering1.Facility__c = parentFacilitiesToInsert[0].Id;
        courseOffering2.Facility__c = parentFacilitiesToInsert[1].Id;
        courseOfferingsToInsert.add(courseOffering1); 
        courseOfferingsToInsert.add(courseOffering2);
        update courseOfferingsToInsert; 

        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();

        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(2, returnParentFacilities.size());
        System.assertEquals(Label.CannotDelete, results[0].errors[0].message);  
    }
    
    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is enabled in Hierarchy Settings, and
    * Facilities has a Facilities or Course Offering record associated to it, then it cannot be deleted.
    */
    @isTest
    public static void cannotDeleteFacilitiesWithSomeChildRecords() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = True));
                            
        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        Facility__c childFacility1 = UTIL_UnitTestData_TEST.getFacility(); 
        childFacility1.Parent_Facility__c = parentFacility.Id; 
        insert childFacility1;
        
        List<Account> department = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, academicAccRecTypeId);
        insert department; 
        Course__c course = new Course__c(Account__c = department[0].Id, Name = 'Bio'); 
        insert course; 
        Term__c term = UTIL_UnitTestData_TEST.getTerm(department[0].Id, 'Fall'); 
        insert term; 
        
        Course_Offering__c courseOffering1 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        courseOffering1.Facility__c = parentFacilitiesToInsert[1].Id;
        update courseOffering1; 
        
        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();
        
        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(2, returnParentFacilities.size());
        System.assertEquals(Label.CannotDelete, results[0].errors[0].message);  
    }
    
    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is disabled in Hierarchy Settings, and
    * Facilities has a Facilities record associated to it, then it can be deleted.
    */
    @isTest
    public static void canDeleteFacilitiesWithFacilities() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = False));
        
        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        List<Facility__c> childFacilitiesToInsert = new List<Facility__c>();
        Facility__c childFacility1 = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c childFacility2 = UTIL_UnitTestData_TEST.getFacility(); 
        childFacility1.Parent_Facility__c = parentFacility.Id; 
        childFacility2.Parent_Facility__c = parentFacility2.Id; 
        childFacilitiesToInsert.add(childFacility1); 
        childFacilitiesToInsert.add(childFacility2); 
        insert childFacilitiesToInsert; 
        
        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();

        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(0, returnParentFacilities.size());
    }
    
    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is disabled in Hierarchy Settings, and
    * Facilities has a Course Offering record associated to it, then it can be deleted.
    */
    @isTest
    public static void canDeleteFacilitiesWithCourseOffering() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = False));
        
        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        List<Account> department = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, academicAccRecTypeId);
        insert department; 
        Course__c course = new Course__c(Account__c = department[0].Id, Name = 'Bio'); 
        insert course; 
        Term__c term = UTIL_UnitTestData_TEST.getTerm(department[0].Id, 'Fall'); 
        insert term; 
        
        List<Course_Offering__c> courseOfferingsToInsert = new List<Course_Offering__c>(); 
        Course_Offering__c courseOffering1 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        Course_Offering__c courseOffering2 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        courseOffering1.Facility__c = parentFacilitiesToInsert[0].Id;
        courseOffering2.Facility__c = parentFacilitiesToInsert[1].Id;
        courseOfferingsToInsert.add(courseOffering1); 
        courseOfferingsToInsert.add(courseOffering2);
        update courseOfferingsToInsert; 
        
        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();

        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(0, returnParentFacilities.size());
    }
    
    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is disabled in Hierarchy Settings, and
    * Facilities has Facilities and Course Offering record associated to it, then it can be deleted.
    */
    @isTest
    public static void canDeleteFacilitiesWithChildRecords() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = False));
        
        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        List<Facility__c> childFacilitiesToInsert = new List<Facility__c>();
        Facility__c childFacility1 = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c childFacility2 = UTIL_UnitTestData_TEST.getFacility(); 
        childFacility1.Parent_Facility__c = parentFacility.Id; 
        childFacility2.Parent_Facility__c = parentFacility2.Id; 
        childFacilitiesToInsert.add(childFacility1); 
        childFacilitiesToInsert.add(childFacility2); 
        insert childFacilitiesToInsert; 
 
        List<Account> department = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, academicAccRecTypeId);
        insert department; 
        Course__c course = new Course__c(Account__c = department[0].Id, Name = 'Bio'); 
        insert course; 
        Term__c term = UTIL_UnitTestData_TEST.getTerm(department[0].Id, 'Fall'); 
        insert term; 
        
        List<Course_Offering__c> courseOfferingsToInsert = new List<Course_Offering__c>(); 
        Course_Offering__c courseOffering1 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        Course_Offering__c courseOffering2 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        courseOffering1.Facility__c = parentFacilitiesToInsert[0].Id;
        courseOffering2.Facility__c = parentFacilitiesToInsert[1].Id;
        courseOfferingsToInsert.add(courseOffering1); 
        courseOfferingsToInsert.add(courseOffering2);
        update courseOfferingsToInsert;  
        
        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();

        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(0, returnParentFacilities.size());
    }

    /*********************************************************************************************************
    * @description Test method to test if Prevent_Facility_Deletion__c is disabled in Hierarchy Settings, and
    * Facilities has Facilities or Course Offering record associated to it, then it can be deleted.
    */
    @isTest
    public static void canDeleteFacilitiesWithSomeChildRecords() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = False));
        
        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        Facility__c childFacility1 = UTIL_UnitTestData_TEST.getFacility(); 
        childFacility1.Parent_Facility__c = parentFacility.Id; 
        insert childFacility1;
        
        List<Account> department = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, academicAccRecTypeId);
        insert department; 
        Course__c course = new Course__c(Account__c = department[0].Id, Name = 'Bio'); 
        insert course; 
        Term__c term = UTIL_UnitTestData_TEST.getTerm(department[0].Id, 'Fall'); 
        insert term; 
        
        Course_Offering__c courseOffering1 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        courseOffering1.Facility__c = parentFacilitiesToInsert[1].Id;
        update courseOffering1; 
        
        Test.startTest();
        Database.DeleteResult[] results = Database.delete(parentFacilitiesToInsert, false);
        Test.stopTest();
        
        List<Facility__c> returnParentFacilities = [SELECT Id
                                                    FROM Facility__c
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        System.assertEquals(0, returnParentFacilities.size());
    }
    
    /*********************************************************************************************************
    * @description Tests the hasChildRecords method that the Facilities record has child records. 
    */
    @isTest
    public static void testFacilitiesHasChildRecords() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = False));
        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        List<Facility__c> childFacilitiesToInsert = new List<Facility__c>();
        Facility__c childFacility1 = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c childFacility2 = UTIL_UnitTestData_TEST.getFacility(); 
        childFacility1.Parent_Facility__c = parentFacility.Id; 
        childFacility2.Parent_Facility__c = parentFacility2.Id; 
        childFacilitiesToInsert.add(childFacility1); 
        childFacilitiesToInsert.add(childFacility2); 
        insert childFacilitiesToInsert; 
        
        List<Account> department = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, academicAccRecTypeId);
        insert department; 
        Course__c course = new Course__c(Account__c = department[0].Id, Name = 'Bio'); 
        insert course; 
        Term__c term = UTIL_UnitTestData_TEST.getTerm(department[0].Id, 'Fall'); 
        insert term; 
        
        List<Course_Offering__c> courseOfferingsToInsert = new List<Course_Offering__c>(); 
        Course_Offering__c courseOffering1 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        Course_Offering__c courseOffering2 = UTIL_UnitTestData_TEST.createCourseOffering(course.Id, term.Id); 
        courseOffering1.Facility__c = parentFacilitiesToInsert[0].Id;
        courseOffering2.Facility__c = parentFacilitiesToInsert[1].Id;
        courseOfferingsToInsert.add(courseOffering1); 
        courseOfferingsToInsert.add(courseOffering2);
        update courseOfferingsToInsert; 
        
        List<Facility__c> returnParentFacilities = [SELECT Id,
                                                    (SELECT Id FROM Facility__c.Facilities__r LIMIT 1), 
                                                    (SELECT Id FROM Facility__c.Course_Offerings__r LIMIT 1)
                                                    FROM Facility__c 
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        FACI_CannotDelete_TDTM myClass = new FACI_CannotDelete_TDTM(); 
        for (Facility__c facilities: returnParentFacilities) {
            System.assertEquals(True, myClass.hasChildRecords(facilities)); 
        }
    }
    
    /*********************************************************************************************************
    * @description Tests the hasChildRecords method that the Facilities record has no child records. 
    */
    @isTest
    public static void testFacilitiesHasNoChildRecords() {
        UTIL_CustomSettingsFacade.getSettingsForTests(new Hierarchy_Settings__c
                                                        (Account_Processor__c = FACI_CannotDelete_TEST.adminAccRecTypeId,
                                                        Prevent_Facility_Deletion__c = False));
        List<Facility__c> parentFacilitiesToInsert = new List<Facility__c>(); 
        Facility__c parentFacility = UTIL_UnitTestData_TEST.getFacility(); 
        Facility__c parentFacility2 = UTIL_UnitTestData_TEST.getFacility();
        parentFacilitiesToInsert.add(parentFacility); 
        parentFacilitiesToInsert.add(parentFacility2); 
        insert parentFacilitiesToInsert; 
        
        List<Facility__c> returnParentFacilities = [SELECT Id,
                                                    (SELECT Id FROM Facility__c.Facilities__r LIMIT 1), 
                                                    (SELECT Id FROM Facility__c.Course_Offerings__r LIMIT 1)
                                                    FROM Facility__c 
                                                    WHERE Id IN :parentFacilitiesToInsert]; 
        FACI_CannotDelete_TDTM myClass = new FACI_CannotDelete_TDTM(); 
        for (Facility__c facilities: returnParentFacilities) {
            System.assertEquals(False, myClass.hasChildRecords(facilities)); 
        }
    }
}
