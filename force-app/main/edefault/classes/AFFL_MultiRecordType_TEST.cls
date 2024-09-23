/*
    Copyright (c) 2015, Salesforce.org
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
 * @date 2015
 * @group Affiliations
 * @group-content ../../ApexDocContent/Affiliations.htm
 * @description Tests specific to Affiliation Management.
 */
@isTest
public with sharing class AFFL_MultiRecordType_TEST {
    private static Integer numberOfTestRecords = 5;
    //Trigger-specific recursion flags
    static final TDTM_ProcessControl.registeredTrigger BEFORE_INSERT_RECURSION = TDTM_ProcessControl.registeredTrigger.AFFL_MultiRecordType_TDTM_Before_Insert;
    static final TDTM_ProcessControl.registeredTrigger AFTER_INSERT_RECURSION = TDTM_ProcessControl.registeredTrigger.AFFL_MultiRecordType_TDTM_After_Insert;
    static final TDTM_ProcessControl.registeredTrigger AFTER_UPDATE_RECURSION = TDTM_ProcessControl.registeredTrigger.AFFL_MultiRecordType_TDTM_After_Update;

    //Special recursion flags
    static final TDTM_ProcessControl.registeredTrigger AFFILIATION_MADE_PRIMARY_RECURSION = TDTM_ProcessControl.registeredTrigger.AFFL_MultiRecordType_TDTM_afflMadePrimary;

    //Cross-trigger recursion flags. Potential antipattern.
    //NOTE: Evaluate if we can improve this
    static final TDTM_ProcessControl.registeredTrigger CONTACT_PRIMARY_AFFILIATION_UPDATED_RECURSION = TDTM_ProcessControl.registeredTrigger.CON_PrimaryAffls_TDTM_keyAfflLookupUpdated;

    /**************************************************************************
     * INTEGRATION TESTS
     **************************************************************************/
    private static void createPrimaryAffl() {
        List<AffiliationTestSetupFactory_TEST.AffiliationMappingWrapper> affiliationMappingWrapperList = AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(
            false
        );
        String bizOrgAcctName = affiliationMappingWrapperList[1].getAccountRecordTypeName();

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Verify default household account has been created for the contact
        contact = [SELECT Account.ID, Primary_Household__c FROM Contact WHERE ID = :Contact.ID];
        System.assertNotEquals(null, contact.Account.ID);
        System.assertEquals(null, contact.Primary_Household__c);
        //Manually create an Affiliation to the household, since we are not automatically doing so any more
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert new Affiliation__c(Contact__c = contact.ID, Account__c = contact.Account.ID, Primary__c = true);

        //Verify the primary household field was populated
        contact = [SELECT Account.ID, Primary_Household__c FROM Contact WHERE ID = :Contact.ID];
        System.assertNotEquals(null, contact.Primary_Household__c);

        //Create account of Business Organization record type
        Account bizOrg1 = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert bizOrg1;

        //Create another key affiliation, this time to a biz org
        Affiliation__c bizAffl1 = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = bizOrg1.ID,
            Primary__c = true
        );
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        Test.startTest();
        insert bizAffl1;
        Test.stopTest();

        //The business organization lookup should point to the account that is part of the affiliation we created
        bizAffl1 = [SELECT Affiliation_Type__c FROM Affiliation__c WHERE Account__c = :bizOrg1.ID];
        System.assertEquals(bizOrgAcctName, bizAffl1.Affiliation_Type__c);

        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(bizOrg1.ID, Contact.Primary_Organization__c);

        //Create second account of the same record type
        Account bizOrg2 = new Account(Name = 'Toys Inc', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert bizOrg2;

        //Create second primary affiliation
        Affiliation__c bizAffl2 = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = bizOrg2.ID,
            Primary__c = true
        );
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert bizAffl2;

        //The previous affiliation should not be the primary any more
        bizAffl1 = [SELECT Primary__c FROM Affiliation__c WHERE ID = :bizAffl1.ID];
        System.assertEquals(false, bizAffl1.Primary__c);

        //The business organization lookup should point to the account that is part of the second affiliation we created
        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(bizOrg2.ID, Contact.Primary_Organization__c);

        //  Test addition of a new affiliation with the same Account doesn't erase the Primary field on Contact

        // Insert another primary Affiliaiton on the Contact with same Account
        Affiliation__c bizAffl3 = new Affiliation__c(
            Contact__c = contact.Id,
            Account__c = bizOrg2.ID,
            Primary__c = true
        );
        insert bizAffl3;

        // Verify Primary Buisness Organization on the Contact is not erased
        Contact updatedContact = [SELECT Id, Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(bizOrg2.ID, updatedContact.Primary_Organization__c);
    }

    @isTest
    private static void noDuplicateAffl() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Create account of Business Organization record type
        Account bizOrg1 = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert bizOrg1;

        //Create primary affiliation
        Affiliation__c bizAffl1 = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = bizOrg1.ID,
            Primary__c = true
        );
        Test.startTest();
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert bizAffl1;
        Test.stopTest();

        //Verify only one Affiliation record to the business account exists. Github #159.
        List<Affiliation__c> affls = [
            SELECT ID
            FROM Affiliation__c
            WHERE Contact__c = :contact.ID AND Account__c = :bizOrg1.ID
        ];
        System.assertEquals(1, affls.size());
    }

    @isTest
    private static void deletePrimaryAffl() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Verify default household account has been created for the contact
        contact = [SELECT Account.ID, Primary_Household__c FROM Contact WHERE ID = :Contact.ID];
        System.assertNotEquals(null, contact.Account.ID);
        System.assertEquals(null, contact.Primary_Household__c);

        //Manually create an Affiliation to the household, since we are not automatically doing so any more.
        insert new Affiliation__c(Contact__c = contact.ID, Account__c = contact.Account.ID, Primary__c = true);

        //Verify the primary household field was populated
        contact = [SELECT Account.ID, Primary_Household__c FROM Contact WHERE ID = :Contact.ID];
        System.assertNotEquals(null, contact.Primary_Household__c);

        //Craete account of Business Organization record type
        Account acc1 = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert acc1;

        //Create primary Business affiliation
        Affiliation__c affl1 = new Affiliation__c(Contact__c = contact.ID, Account__c = acc1.ID, Primary__c = true);
        Test.startTest();
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert affl1;
        Test.stopTest();

        //Verify Primary Organization lookup field points to the account we just created
        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(acc1.ID, Contact.Primary_Organization__c);

        //Delete Business affiliation
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        delete affl1;

        //Verify Primary Organization lookup field has been cleared
        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(null, Contact.Primary_Organization__c);
    }

    @isTest
    private static void makePrimaryAfflNonPrimary() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Verify default household account has been created for the contact
        contact = [SELECT Account.ID, Primary_Household__c FROM Contact WHERE ID = :Contact.ID];
        System.assertNotEquals(null, contact.Account.ID);
        ID parentAccountId = contact.Account.ID;
        System.assertEquals(null, contact.Primary_Household__c);

        //Manually create an Affiliation to the household, since we are not automatically doing so any more.
        Affiliation__c affl = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = contact.Account.ID,
            Primary__c = true
        );
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert affl;

        //Verify the primary household field was populated
        contact = [SELECT Account.ID, Primary_Household__c FROM Contact WHERE ID = :Contact.ID];
        System.assertNotEquals(null, contact.Primary_Household__c);

        //Make the affiliation not primary
        affl.Primary__c = false;
        Test.startTest();
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        update affl;
        Test.stopTest();

        //Verify Primary_Household__c field has been cleared
        contact = [SELECT Account.ID, Primary_Household__c FROM Contact WHERE ID = :Contact.ID];
        System.assertEquals(null, contact.Primary_Household__c);

        //Verify the contact is still the child of the same account
        System.assertEquals(parentAccountId, contact.Account.ID);
    }

    @isTest
    private static void updatePrimaryAffiliationRecordType_FieldNames() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);
        Test.startTest();
        updatePrimaryAfflAccountRecordType();
        Test.stopTest();
    }

    /*
     * Ensure account record type changes are appropriated reflected upon contact fields/affiliations.
     * Test Scenario: T-3938997
     */
    private static void updatePrimaryAfflAccountRecordType() {
        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        Account affiliatedBizAcct = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        Account affiliatedHHAcct = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getHhAccRecTypeID());
        insert new List<Account>{ affiliatedBizAcct, affiliatedHHAcct };

        contact.Primary_Organization__c = affiliatedBizAcct.Id;
        contact.Primary_Household__c = affiliatedHHAcct.Id;
        update contact;

        affiliatedHHAcct.RecordTypeId = UTIL_Describe.getBizAccRecTypeID();
        update affiliatedHHAcct;

        contact = [SELECT Id, Primary_Household__c, Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(affiliatedHHAcct.Id, contact.Primary_Organization__c);
        System.assertEquals(null, contact.Primary_Household__c);

        Affiliation__c initialBizAffl = [
            SELECT Id, Primary__c, Affiliation_Type__c
            FROM Affiliation__c
            WHERE Contact__c = :contact.Id AND Account__c = :affiliatedBizAcct.Id
        ];

        Affiliation__c finalBizAffl = [
            SELECT Id, Primary__c, Affiliation_Type__c
            FROM Affiliation__c
            WHERE Contact__c = :contact.Id AND Account__c = :affiliatedHHAcct.Id
        ];

        System.assertEquals('Business Organization', initialBizAffl.Affiliation_Type__c);
        System.assertEquals('Business Organization', finalBizAffl.Affiliation_Type__c);
        System.assertEquals(false, initialBizAffl.Primary__c);
        System.assertEquals(true, finalBizAffl.Primary__c);
    }

    @isTest
    private static void makeNonPrimaryAfflPrimary() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Create account of Business Organization record type
        Account acc1 = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert acc1;

        //Create non-primary Business affiliation
        Affiliation__c affl1 = new Affiliation__c(Contact__c = contact.ID, Account__c = acc1.ID, Primary__c = false);
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert affl1;

        //Verify Primary Organization lookup field is blank
        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(null, Contact.Primary_Organization__c);

        //Make the business affiliation primary
        affl1.Primary__c = true;
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        Test.startTest();
        update affl1;
        Test.stopTest();

        //Verify key affl field has been populated
        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(acc1.ID, Contact.Primary_Organization__c);

        //No other affiliation should have been created (bug W-008631)
        List<Affiliation__c> affls = [SELECT ID FROM Affiliation__c WHERE Contact__c = :contact.ID];
        System.assertEquals(1, affls.size());
    }

    @isTest
    private static void makeNonPrimaryAfflPrimaryWhenAnotherPrimaryExists() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Create 2 accounts of Business Organization record type
        Account acc1 = new Account(Name = 'Acme1', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        Account acc2 = new Account(Name = 'Acme2', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert new List<Account>{ acc1, acc2 };

        //Create primary Business affiliation
        Affiliation__c affl1 = new Affiliation__c(Contact__c = contact.ID, Account__c = acc1.ID, Primary__c = true);
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert affl1;

        //Verify key affl field has been populated
        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(acc1.ID, Contact.Primary_Organization__c);

        //Create non-primary Business affiliation
        Affiliation__c affl2 = new Affiliation__c(Contact__c = contact.ID, Account__c = acc2.ID, Primary__c = false);
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert affl2;

        //Made the second business affiliation primary
        affl2.Primary__c = true;
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        Test.startTest();
        update affl2;
        Test.stopTest();

        //The second affiliation should be the only primary so order by Primary ASC
        //to ensure we recieve the Primary = True as the second record. Verify
        //its affiliiation with acc2.
        List<Affiliation__c> affls = [
            SELECT Account__c, Primary__c
            FROM Affiliation__c
            WHERE Contact__c = :contact.ID
            ORDER BY Primary__c ASC
        ];
        System.assertEquals(affls[0].Account__c, acc1.ID);
        System.assertEquals(affls[0].Primary__c, false);
        System.assertEquals(affls[1].Account__c, acc2.ID);
        System.assertEquals(affls[1].Primary__c, true);

        //Verify key affl field has been updated
        contact = [SELECT Primary_Organization__c FROM Contact WHERE ID = :contact.ID];
        System.assertEquals(acc2.ID, Contact.Primary_Organization__c);
    }

    /* Ensure additional affiliations created render previous affiliations as non-primary.
     *  Test Scenario: T-3938989
     */
    @isTest
    private static void createPrimaryAfflWhenAnotherPrimaryExists() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Create 2 accounts of Business Organization record type
        Account primaryAcct = new Account(Name = 'Acme1', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        Account secondaryAcct = new Account(Name = 'Acme2', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert new List<Account>{ primaryAcct, secondaryAcct };

        //Create primary Business affiliation
        Affiliation__c primaryAffiliation = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = primaryAcct.ID,
            Primary__c = true
        );
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert primaryAffiliation;

        primaryAffiliation = [SELECT Id, Account__c, Primary__c FROM Affiliation__c WHERE Id = :primaryAffiliation.Id];
        System.assertEquals(true, primaryAffiliation.Primary__c);

        //Create second primary Business affiliation
        Affiliation__c secondaryAffiliation = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = secondaryAcct.ID,
            Primary__c = true
        );
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        Test.startTest();
        insert secondaryAffiliation;
        Test.stopTest();

        Map<ID, Affiliation__c> allAffiliations = new Map<ID, Affiliation__c>(
            [SELECT Id, Account__c, Primary__c FROM Affiliation__c]
        );

        System.assertNotEquals(null, allAffiliations.get(primaryAffiliation.Id));
        System.assertEquals(false, allAffiliations.get(primaryAffiliation.Id).Primary__c);
        System.assertNotEquals(null, allAffiliations.get(secondaryAffiliation.Id));
        System.assertEquals(true, allAffiliations.get(secondaryAffiliation.Id).Primary__c);
    }

    @isTest
    private static void autoCreateProgramEnrollment() {
        List<AffiliationTestSetupFactory_TEST.AffiliationMappingWrapper> affiliationMappingWrapperList = AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(
            false
        );

        AffiliationTestSetupFactory_TEST.AffiliationMappingWrapper bizOrgMappingWrapper = affiliationMappingWrapperList[1];
        String bizOrgRecordTypeName = bizOrgMappingWrapper.getAccountRecordTypeName();

        //Turn on Academic Record auto-creation for Business Organization mapping, which we are using as an arbitrary record type for testing.
        Affl_Mappings__c bizOrgMapping = bizOrgMappingWrapper.getAffiliationMapping();
        bizOrgMapping.Auto_Program_Enrollment__c = true;
        bizOrgMapping.Auto_Program_Enrollment_Role__c = AffiliationTestSetupFactory_TEST.PROG_ENROLL_ROLE_STUDENT;
        bizOrgMapping.Auto_Program_Enrollment_Status__c = AffiliationTestSetupFactory_TEST.PROG_ENROLL_STATUS_CURRENT;
        update bizOrgMapping;

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Craete account of Business Organization record type
        Account acc = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert acc;

        //Create Business affiliation
        Affiliation__c affl = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = acc.ID,
            Role__c = AffiliationTestSetupFactory_TEST.PROG_ENROLL_ROLE_STUDENT,
            Status__c = AffiliationTestSetupFactory_TEST.PROG_ENROLL_STATUS_CURRENT
        );

        Test.startTest();
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert affl;
        Test.stopTest();
        //Verify Progran Enrollment record has been created
        List<Program_Enrollment__c> programEnrollments = [
            SELECT ID, Contact__c
            FROM Program_Enrollment__c
            WHERE Affiliation__c = :affl.ID
        ];
        System.assertEquals(1, programEnrollments.size());
        System.assertEquals(contact.ID, programEnrollments[0].Contact__c);
    }

    @isTest
    private static void autoCreateProgramEnrollmentDifferentRole() {
        List<AffiliationTestSetupFactory_TEST.AffiliationMappingWrapper> affiliationMappingWrapperList = AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(
            false
        );

        AffiliationTestSetupFactory_TEST.AffiliationMappingWrapper bizOrgMappingWrapper = affiliationMappingWrapperList[1];
        String bizOrgRecordTypeName = bizOrgMappingWrapper.getAccountRecordTypeName();

        //Turn on Academic Record auto-creation for Business Organization mapping, which we are using as an arbitrary record type for testing.
        Affl_Mappings__c bizOrgMapping = bizOrgMappingWrapper.getAffiliationMapping();
        bizOrgMapping.Auto_Program_Enrollment__c = true;
        bizOrgMapping.Auto_Program_Enrollment_Role__c = AffiliationTestSetupFactory_TEST.PROG_ENROLL_ROLE_STUDENT;
        bizOrgMapping.Auto_Program_Enrollment_Status__c = AffiliationTestSetupFactory_TEST.PROG_ENROLL_STATUS_CURRENT;
        update bizOrgMapping;

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact;

        //Craete account of Business Organization record type
        Account acc = new Account(Name = 'Acme', RecordTypeId = UTIL_Describe.getBizAccRecTypeID());
        insert acc;

        //Create Business affiliation
        Affiliation__c affl = new Affiliation__c(
            Contact__c = contact.ID,
            Account__c = acc.ID,
            Role__c = 'Teacher',
            Status__c = AffiliationTestSetupFactory_TEST.PROG_ENROLL_STATUS_CURRENT
        );

        Test.startTest();
        AFFL_ContactAccChange_TEST.resetAfflFlags();
        insert affl;
        Test.stopTest();

        //Verify Program Enrollment record has not been created
        List<Program_Enrollment__c> programEnrollments = [
            SELECT ID, Contact__c
            FROM Program_Enrollment__c
            WHERE Affiliation__c = :affl.ID
        ];
        System.assertEquals(0, programEnrollments.size());
    }

    /*********************************************************************************************************
     * @description
     * This method ensures there is no NPE when a primay affiliation
     * with no contact is deleted
     */
    @isTest
    private static void affiliationDeleteNPECheck() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        // Insert a business account
        Account bizAcc = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        insert bizAcc;

        // Insert a contact
        Contact contact = UTIL_UnitTestData_API.getContact();
        insert contact;

        //Insert a primary affiliation
        Affiliation__c affl = new Affiliation__c(Contact__c = contact.Id, Account__c = bizAcc.Id, Primary__c = true);
        insert affl;

        //Verify 1 affiliation is created
        List<Affiliation__c> affiliationList = [
            SELECT Id, Name, Contact__c, Primary__c
            FROM Affiliation__c
            WHERE Contact__c = :contact.Id AND Account__c = :bizAcc.Id
        ];

        System.assertEquals(1, affiliationList.size());
        System.assertEquals(true, affiliationList[0].Primary__c);

        // Clear the value of contact on affiliation
        affiliationList[0].Contact__c = null;
        update affiliationList;

        // delete affiliation
        Test.startTest();

        delete affiliationList;

        Test.stopTest();

        //Verify affiliation is deleted and no NPE
        List<Affiliation__c> allAffiliationList = [
            SELECT Id, Name, Primary__c
            FROM Affiliation__c
            WHERE Contact__c = :contact.Id AND Account__c = :bizAcc.Id
        ];

        System.assertEquals(0, allAffiliationList.size());
    }

    /*********************************************************************************************************
     * @description
     * This method ensures concurrent updates to multiple affiliation records as Primary populates correct
     * Primary fields on related Contact
     */
    @isTest
    private static void multipleAffiliationUpdates() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        // Insert Accounts
        Account bizAcc1 = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        Account bizAcc2 = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        Account hhAcc1 = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getCustomHHAccRecTypeID())[0];
        Account hhAcc2 = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getCustomHHAccRecTypeID())[0];

        insert new List<Account>{ bizAcc1, bizAcc2, hhAcc1, hhAcc2 };

        // Insert a Contact
        Contact contact1 = UTIL_UnitTestData_API.getContact();
        Contact contact2 = UTIL_UnitTestData_API.getContact();
        insert new List<Contact>{ contact1, contact2 };

        //Insert primary and non-primary Affiliations
        Affiliation__c affl1 = UTIL_UnitTestData_TEST.getAffiliation(contact1.Id, bizAcc1.Id, true);
        Affiliation__c affl2 = UTIL_UnitTestData_TEST.getAffiliation(contact1.Id, bizAcc2.Id, false);
        Affiliation__c affl3 = UTIL_UnitTestData_TEST.getAffiliation(contact1.Id, hhAcc1.Id, true);
        Affiliation__c affl4 = UTIL_UnitTestData_TEST.getAffiliation(contact1.Id, hhAcc2.Id, false);

        Affiliation__c affl5 = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, bizAcc1.Id, true);
        Affiliation__c affl6 = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, bizAcc2.Id, false);
        Affiliation__c affl7 = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, hhAcc1.Id, true);
        Affiliation__c affl8 = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, hhAcc2.Id, false);

        insert new List<Affiliation__c>{ affl1, affl2, affl3, affl4, affl5, affl6, affl7, affl8 };

        for (Contact eachCon : [SELECT Id, Primary_Organization__c, Primary_Household__c FROM Contact]) {
            // Ensure Primary fields on Contact are populated
            System.assertEquals(eachCon.Primary_Organization__c, bizAcc1.Id);
            System.assertEquals(eachCon.Primary_Household__c, hhAcc1.Id);
        }

        // Make non-primary Affliations as primary
        List<Affiliation__c> afflList = new List<Affiliation__c>();
        for (Affiliation__c eachAffl : [SELECT Id, Primary__c FROM Affiliation__c WHERE Primary__c = FALSE]) {
            eachAffl.Primary__c = true;
            afflList.add(eachAffl);
        }

        Test.startTest();
        if (afflList.size() > 0) {
            update afflList;
        }
        Test.stopTest();

        for (contact conAfterUpdate : [SELECT Id, Primary_Organization__c, Primary_Household__c FROM Contact]) {
            // Ensure Primary fields on Contact are populated with new Accounts
            System.assertEquals(conAfterUpdate.Primary_Organization__c, bizAcc2.Id);
            System.assertEquals(conAfterUpdate.Primary_Household__c, hhAcc2.Id);
        }
        // Ensure old Affliations are made non-primary
        for (Affiliation__c eachAffl : [
            SELECT Id, Primary__c
            FROM Affiliation__c
            WHERE
                (Contact__c = :contact1.Id
                OR Contact__c = :contact2.Id)
                AND (Account__c = :bizAcc1.Id
                OR Account__c = :hhAcc1.Id)
        ]) {
            System.assertEquals(eachAffl.Primary__c, false);
        }
    }

    /*********************************************************************************************************
     * @description
     * This bulk test method ensures Multiple affiliations to the same Business Organization don't
     * prevent Primary fields on Contacts from updating
     */
    @isTest
    private static void bulkAffiliationUpdates() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);

        List<Account> accList = new List<Account>();

        // Insert a Business Account
        Account bizAcc = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        accList.add(bizAcc);

        // Insert a Household Account
        Account hhAcc = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getCustomHHAccRecTypeID())[0];
        accList.add(hhAcc);

        // Insert multiple contacts
        List<Contact> conList = UTIL_UnitTestData_Test.getMultipleTestContacts(3);
        insert conList;

        // Insert 3 Primay Business Affiliations
        List<Affiliation__c> afflList = new List<Affiliation__c>();
        for (Contact each : conList) {
            Affiliation__c affl = UTIL_UnitTestData_TEST.getAffiliation(each.Id, bizAcc.Id, true);
            afflList.add(affl);
        }
        insert afflList;

        // Verify Primary Buisness Organization is populated on the Contact
        for (Contact eachContact : [SELECT Id, Primary_Organization__c FROM Contact]) {
            System.assertEquals(bizAcc.Id, eachContact.Primary_Organization__c);
        }

        // Insert a contact
        Contact contact2 = UTIL_UnitTestData_API.getContact();
        insert contact2;

        // Insert 1 non-primary business affiliation and 1 primary household affiliation
        List<Affiliation__c> newAfflList = new List<Affiliation__c>();
        Affiliation__c afflBizAcc = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, bizAcc.Id, false);
        Affiliation__c afflAcad = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, hhAcc.Id, true);
        newAfflList.add(afflBizAcc);
        newAfflList.add(afflAcad);
        insert newAfflList;

        // Ensure Primary Organization is NULL and household affiliation is populated
        Contact con = [SELECT Id, Primary_Organization__c, Primary_Household__c FROM Contact WHERE Id = :contact2.Id];
        System.assertEquals(null, con.Primary_Organization__c);
        System.assertEquals(hhAcc.Id, con.Primary_Household__c);

        // Insert Affiliations on the Contacts with the same Account as the Primary Organization
        // Change the Primary Academic Affiliation to non-primary
        List<Affiliation__c> afflListNew = new List<Affiliation__c>();
        for (Contact each : conList) {
            Affiliation__c affl1 = UTIL_UnitTestData_TEST.getAffiliation(each.Id, bizAcc.Id, true);
            afflListNew.add(affl1);
        }
        Affiliation__c afflBiz = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, bizAcc.Id, true);
        Affiliation__c hhAffl1 = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, hhAcc.Id, true);
        Affiliation__c hhAffl2 = UTIL_UnitTestData_TEST.getAffiliation(contact2.Id, hhAcc.Id, false);
        afflListNew.add(hhAffl1);
        afflListNew.add(hhAffl2);
        afflListNew.add(afflBiz);

        test.startTest();
        upsert afflListNew;
        test.stopTest();

        // Verify Primary Buisness Organization on Contacts are not erased
        for (Contact eachContact : [SELECT Id, Primary_Organization__c FROM Contact]) {
            System.assertEquals(bizAcc.Id, eachContact.Primary_Organization__c);
        }

        // Ensure Primary Household are populated
        Contact conAfterUpdate = [SELECT Id, Primary_Household__c FROM Contact WHERE Id = :contact2.Id];
        System.assertEquals(hhAcc.Id, conAfterUpdate.Primary_Household__c);
    }

    // Test the usage of custom API field name for affiliation mapping for multi-language support
    @isTest
    private static void customFieldAPIInMappings() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndApiName(false);

        // Insert a business account
        Account bizAcc = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        insert bizAcc;

        // Insert a contact with business account as Primary business organization
        Contact contact = UTIL_UnitTestData_API.getContact();
        insert contact;

        Affiliation__c affl = new Affiliation__c(Contact__c = contact.Id, Account__c = bizAcc.Id, Primary__c = true);
        test.startTest();
        //Insert an affiliation
        insert affl;
        test.stopTest();

        //Verify Primary Organization is populated
        Contact updatedContact = [SELECT Id, Primary_Organization__c FROM Contact WHERE Id = :contact.Id];

        System.assertEquals(bizAcc.Id, updatedContact.Primary_Organization__c);
    }

    /* Test deletion of an Affiliation clears the Primary Affiliation field on its Contact when Affiliation Mappings
     have Label for Account Record Types and APIs for Primary Affiliation fields. */

    @isTest
    private static void testAfflDeletionWithLabelForRecTypeAndAPINameForPrimaryAfflFields() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndApiName(false);

        // Insert a business account
        Account bizAcc = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        insert bizAcc;

        // Insert a contact with business account as Primary business organization
        Contact contact = UTIL_UnitTestData_API.getContact();
        insert contact;

        // Insert an affiliation
        Affiliation__c affiliation = new Affiliation__c(
            Contact__c = contact.Id,
            Account__c = bizAcc.Id,
            Primary__c = true
        );
        insert affiliation;

        // Verify Primary Organization lookup field points to the account we just created
        contact = [SELECT Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(bizAcc.ID, Contact.Primary_Organization__c);

        Test.startTest();
        delete affiliation;
        Test.stopTest();

        // Verify Primary Organization lookup field has been cleared
        contact = [SELECT Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(null, Contact.Primary_Organization__c);
    }

    /* Test deletion of an Affiliation clears the Primary Affiliation field on its Contact when Affiliation Mappings
     have API names for Account Record Types and Labels for Primary Affiliation fields. */

    @isTest
    private static void testAfflDeletionWithAPIForRecTypeAndLabelForPrimaryAfflFields() {
        AffiliationTestSetupFactory_TEST.setupMappingsByDevNameAndLabel(false);

        // Insert a business account
        Account bizAcc = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        insert bizAcc;

        // Insert a contact with business account as Primary business organization
        Contact contact = UTIL_UnitTestData_API.getContact();
        insert contact;

        // Insert an affiliation
        Affiliation__c affiliation = new Affiliation__c(
            Contact__c = contact.Id,
            Account__c = bizAcc.Id,
            Primary__c = true
        );
        insert affiliation;

        // Verify Primary Organization lookup field points to the account we just created
        contact = [SELECT Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(bizAcc.ID, Contact.Primary_Organization__c);

        Test.startTest();
        delete affiliation;
        Test.stopTest();

        // Verify Primary Organization lookup field has been cleared
        contact = [SELECT Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(null, Contact.Primary_Organization__c);
    }

    /* Test deletion of an Affiliation clears the Primary Affiliation field on its Contact when Affiliation Mappings
     have API names for Account Record Types and API for Primary Affiliation fields. */

    @isTest
    private static void testAfflDeletionWithAPIForRecTypeAndAPIForPrimaryAfflFields() {
        AffiliationTestSetupFactory_TEST.setupMappingsByDevNameAndApiName(false);

        // Insert a business account
        Account bizAcc = UTIL_UnitTestData_API.getMultipleTestAccounts(1, UTIL_Describe.getBizAccRecTypeID())[0];
        insert bizAcc;

        // Insert a contact with business account as Primary business organization
        Contact contact = UTIL_UnitTestData_API.getContact();
        insert contact;

        // Insert an affiliation
        Affiliation__c affiliation = new Affiliation__c(
            Contact__c = contact.Id,
            Account__c = bizAcc.Id,
            Primary__c = true
        );
        insert affiliation;

        // Verify Primary Organization lookup field points to the account we just created
        contact = [SELECT Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(bizAcc.ID, Contact.Primary_Organization__c);

        Test.startTest();
        delete affiliation;
        Test.stopTest();

        // Verify Primary Organization lookup field has been cleared
        contact = [SELECT Primary_Organization__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(null, Contact.Primary_Organization__c);
    }

    /* Test to ensure users can create Contacts and Affiliations when Affiliation Record Type Enforced is enabled in EDA Settings
     and Affilation Mappings have Record Type Names for Account Record Type */
    @isTest
    private static void affiliationRecordTypeEnforceWAPINamesForAccRecType() {
        AffiliationTestSetupFactory_TEST.setupMappingsByDevNameAndLabel(false);
        AffiliationTestSetupFactory_TEST.enableAffiliationRecordTypeEnforcement();

        List<Account> testAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            1,
            UTIL_Describe.getBizAccRecTypeID()
        );
        insert testAccounts;

        // Ensure Accounts are inserted
        List<Account> accountsInserted = [SELECT Id FROM Account];
        System.assert(accountsInserted.size() == 1);

        // Insert 4 Contacts
        List<Contact> contactsToBeInserted = UTIL_UnitTestData_TEST.getMultipleTestContacts(3);
        Contact testContact = UTIL_UnitTestData_TEST.getUniqueContact(1);
        testContact.Primary_Organization__c = testAccounts[0].Id;
        contactsToBeInserted.add(testContact);
        insert contactsToBeInserted;

        // Ensure 4 Contacts are inserted
        List<Contact> contactsInserted = [SELECT Id FROM Contact];
        System.assertEquals(contactsInserted.size(), 4);

        // Ensure only 1 affiliation is created for testContact
        List<Affiliation__c> affiliationsBeforeInserted = [SELECT Id, Contact__c FROM Affiliation__c];
        System.assertEquals(1, affiliationsBeforeInserted.size());
        System.assertEquals(testContact.Id, affiliationsBeforeInserted[0].Contact__c);

        // Create 1 affiliaton each for a Contact
        List<Affiliation__c> affiliationsToBeInserted = new List<Affiliation__c>();
        for (Contact each : contactsInserted) {
            Affiliation__c affl = UTIL_UnitTestData_TEST.getAffiliation(each.Id, accountsInserted[0].Id, false);
            affiliationsToBeInserted.add(affl);
        }

        Test.startTest();
        insert affiliationsToBeInserted;
        Test.stopTest();

        // Ensure 4 new Affiliations are inserted
        List<Affiliation__c> affiliationsInserted = [SELECT Id FROM Affiliation__c];
        System.assertEquals(5, affiliationsInserted.size());
    }

    /* Test to ensure users can create Contacts and Affiliations when Affiliation Record Type Enforced is enabled in EDA Settings
     and Affiliation Mappings have Record Type Labels for Account Record Type */

    @isTest
    private static void affiliationRecordTypeEnforceWLabelsForAccRecType() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndLabel(false);
        AffiliationTestSetupFactory_TEST.enableAffiliationRecordTypeEnforcement();

        List<Account> testAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            1,
            UTIL_Describe.getBizAccRecTypeID()
        );
        insert testAccounts;

        // Ensure Accounts are inserted
        List<Account> accountsInserted = [SELECT Id FROM Account];
        System.assert(accountsInserted.size() == 1);

        // Insert 4 Contacts
        List<Contact> contactsToBeInserted = UTIL_UnitTestData_TEST.getMultipleTestContacts(3);
        Contact testContact = UTIL_UnitTestData_TEST.getUniqueContact(1);
        testContact.Primary_Organization__c = testAccounts[0].Id;
        contactsToBeInserted.add(testContact);
        insert contactsToBeInserted;

        // Ensure 4 Contacts are inserted
        List<Contact> contactsInserted = [SELECT Id FROM Contact];
        System.assertEquals(contactsInserted.size(), 4);

        // Ensure only 1 affiliation is created for testContact
        List<Affiliation__c> affiliationsBeforeInserted = [SELECT Id, Contact__c FROM Affiliation__c];
        System.assertEquals(1, affiliationsBeforeInserted.size());
        System.assertEquals(testContact.Id, affiliationsBeforeInserted[0].Contact__c);

        // Create 1 affiliation each for a Contact
        List<Affiliation__c> affiliationsToBeInserted = new List<Affiliation__c>();

        for (Contact each : contactsInserted) {
            Affiliation__c affl = UTIL_UnitTestData_TEST.getAffiliation(each.Id, accountsInserted[0].Id, false);
            affiliationsToBeInserted.add(affl);
        }

        Test.startTest();
        insert affiliationsToBeInserted;
        Test.stopTest();

        // Ensure 4 new Affiliations are inserted
        List<Affiliation__c> affiliationsInserted = [SELECT Id FROM Affiliation__c];
        System.assertEquals(5, affiliationsInserted.size());
    }

    /* Test to ensure users can create Contacts and Affiliations when Affiliation Record Type Enforced is enabled in EDA Settings
     and Affiliation Mappings have API names for Account Record Type and primary Affiliaiton Fields */

    @isTest
    private static void affiliationRecordTypeEnforceWAPINamesForAccRecTypeAndPrimaryAffl() {
        AffiliationTestSetupFactory_TEST.setupMappingsByDevNameAndApiName(false);
        AffiliationTestSetupFactory_TEST.enableAffiliationRecordTypeEnforcement();

        List<Account> testAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            1,
            UTIL_Describe.getBizAccRecTypeID()
        );
        insert testAccounts;

        // Ensure Accounts are inserted
        List<Account> accountsInserted = [SELECT Id FROM Account];
        System.assert(accountsInserted.size() == 1);

        // Insert 4 Contacts
        List<Contact> contactsToBeInserted = UTIL_UnitTestData_TEST.getMultipleTestContacts(3);
        Contact testContact = UTIL_UnitTestData_TEST.getUniqueContact(1);
        testContact.Primary_Organization__c = testAccounts[0].Id;
        contactsToBeInserted.add(testContact);
        insert contactsToBeInserted;

        // Ensure 4 Contacts are inserted
        List<Contact> contactsInserted = [SELECT Id FROM Contact];
        System.assertEquals(contactsInserted.size(), 4);

        // Ensure only 1 affiliation is created for testContact
        List<Affiliation__c> affiliationsBeforeInserted = [SELECT Id, Contact__c FROM Affiliation__c];
        System.assertEquals(1, affiliationsBeforeInserted.size());
        System.assertEquals(testContact.Id, affiliationsBeforeInserted[0].Contact__c);

        // Create 1 affiliation each for a Contact
        List<Affiliation__c> affiliationsToBeInserted = new List<Affiliation__c>();
        for (Contact each : contactsInserted) {
            Affiliation__c affl = UTIL_UnitTestData_TEST.getAffiliation(each.Id, accountsInserted[0].Id, false);
            affiliationsToBeInserted.add(affl);
        }

        Test.startTest();
        insert affiliationsToBeInserted;
        Test.stopTest();

        // Ensure 4 new Affiliations are inserted
        List<Affiliation__c> affiliationsInserted = [SELECT Id FROM Affiliation__c];
        System.assertEquals(5, affiliationsInserted.size());
    }

    /* Test to ensure users can create Contacts and Affiliations when Affiliation Record Type Enforced is enabled in EDA Settings
     and Affiliation Mappings have Labels for Account Record Type and APIs for Primary Affiliaiton Fields */
    @isTest
    private static void affiliationRecordTypeEnforceWLabelsForAccRecTypeAndAPIForPrimaryAffl() {
        AffiliationTestSetupFactory_TEST.setupMappingsByNameAndApiName(false);
        AffiliationTestSetupFactory_TEST.enableAffiliationRecordTypeEnforcement();

        List<Account> testAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            1,
            UTIL_Describe.getBizAccRecTypeID()
        );
        insert testAccounts;

        // Ensure Accounts are inserted
        List<Account> accountsInserted = [SELECT Id FROM Account];
        System.assert(accountsInserted.size() == 1);

        // Insert 4 Contacts
        List<Contact> contactsToBeInserted = UTIL_UnitTestData_TEST.getMultipleTestContacts(3);
        Contact testContact = UTIL_UnitTestData_TEST.getUniqueContact(1);
        testContact.Primary_Organization__c = testAccounts[0].Id;
        contactsToBeInserted.add(testContact);
        insert contactsToBeInserted;

        // Ensure 4 Contacts are inserted
        List<Contact> contactsInserted = [SELECT Id FROM Contact];
        System.assertEquals(contactsInserted.size(), 4);

        // Ensure only 1 affiliation is created for testContact
        List<Affiliation__c> affiliationsBeforeInserted = [SELECT Id, Contact__c FROM Affiliation__c];
        System.assertEquals(1, affiliationsBeforeInserted.size());
        System.assertEquals(testContact.Id, affiliationsBeforeInserted[0].Contact__c);

        // Create 1 affiliation each for a Contact
        List<Affiliation__c> affiliationsToBeInserted = new List<Affiliation__c>();
        for (Contact each : contactsInserted) {
            Affiliation__c affl = UTIL_UnitTestData_TEST.getAffiliation(each.Id, accountsInserted[0].Id, false);
            affiliationsToBeInserted.add(affl);
        }

        Test.startTest();
        insert affiliationsToBeInserted;
        Test.stopTest();

        // Ensure 4 new Affiliations are inserted
        List<Affiliation__c> affiliationsInserted = [SELECT Id FROM Affiliation__c];
        System.assertEquals(5, affiliationsInserted.size());
    }

    /**************************************************************************
     * Unit TESTS
     *************************************************************************/

    /****************************************
     * handleAfterInsert
     ****************************************/

    /**
     * @description helper class for initialization of tests for handleAfterInsert
     */
    private class HandleAfterInsertValidData {
        public AFFL_MultiRecordType_TDTM tdtmClass;
        public TDTM_Runnable.DmlWrapper dmlWrapper;
        public Account accountToTest;
        public Contact contactToTest;
        public Affiliation__c affiliation;

        public HandleAfterInsertValidData() {
            this.tdtmClass = new AFFL_MultiRecordType_TDTM();
            this.dmlWrapper = new TDTM_Runnable.DmlWrapper();
            this.contactToTest = UTIL_UnitTestData_TEST.getUniqueContact(1);
            insert contactToTest;

            Id businessOrganizationRecordTypeId = UTIL_Describe.getBizAccRecTypeID();
            this.accountToTest = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, businessOrganizationRecordTypeId)[0];
            insert this.accountToTest;

            this.affiliation = new Affiliation__c(
                Id = UTIL_UnitTestData_TEST.getFakeId(Affiliation__c.SObjectType),
                Account__c = this.accountToTest.Id,
                Contact__c = this.contactToTest.Id,
                Primary__c = true
            );
        }
    }

    /**
     * @description Tests handleAfterInsert appropriately calls createProgramEnrollmentIfNecessary
     */
    private static void handleAfterInsertValid() {
        HandleAfterInsertValidData testData = new HandleAfterInsertValidData();
        AFFL_MultiRecordType_TDTM.afflMapper = new AFFL_MultiRecordTypeMapper_STUB(true);
        Formula.recalculateFormulas(new List<Affiliation__c>{ testData.affiliation });

        List<SObject> newList = new List<SObject>();
        newList.add(testData.affiliation);

        Test.startTest();
        TDTM_Runnable.DMLWrapper dmlWrapperReturned = testData.tdtmClass.handleAfterInsert(
            newList,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            true,
            testData.tdtmClass.isAfterInsertRecursion(),
            'After insert recursion for should be active for AFFL_MultiRecordType_TDTM.'
        );

        System.assertEquals(
            1,
            dmlWrapperReturned.objectsToInsert.size(),
            'The DMLWrapper should contain a single program enrollment to insert.'
        );

        for (SObject sObjectRetrieved : dmlWrapperReturned.objectsToInsert) {
            Program_Enrollment__c programEnrollment = (Program_Enrollment__c) sObjectRetrieved;

            System.assertEquals(
                testData.affiliation.Account__c,
                programEnrollment.Account__c,
                'The Account of the created Program Enrollment should match the provided Affiliation\'s.'
            );
            System.assertEquals(
                testData.affiliation.Contact__c,
                programEnrollment.Contact__c,
                'The Contact of the created Program Enrollment should match the provided Affiliation\'s.'
            );
            System.assertEquals(
                testData.affiliation.Id,
                programEnrollment.Affiliation__c,
                'The Affiliation of the created Program Enrollment should be the provided Affiliation\'s.'
            );
        }
    }

    /**
     * @description Tests handleAfterInsert appropriately calls createProgramEnrollmentIfNecessary and does not create a Program Enrollment
     */
    private static void handleAfterInsertInvalid() {
        HandleAfterInsertValidData testData = new HandleAfterInsertValidData();
        AFFL_MultiRecordType_TDTM.afflMapper = new AFFL_MultiRecordTypeMapper_STUB(false);
        Formula.recalculateFormulas(new List<Affiliation__c>{ testData.affiliation });

        List<SObject> newList = new List<SObject>();
        newList.add(testData.affiliation);

        Test.startTest();
        TDTM_Runnable.DMLWrapper dmlWrapperReturned = testData.tdtmClass.handleAfterInsert(
            newList,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            true,
            testData.tdtmClass.isAfterInsertRecursion(),
            'After insert recursion for should be active for AFFL_MultiRecordType_TDTM.'
        );

        System.assertEquals(true, dmlWrapperReturned.objectsToInsert.isEmpty(), 'The DMLWrapper should be empty.');
    }

    /**
     * @description Tests handleAfterInsert only sets after insert recursion on an empty new list
     */
    private static void handleAfterInsertNewListEmpty() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        List<SObject> newList = new List<SObject>();

        Test.startTest();
        TDTM_Runnable.DMLWrapper dmlWrapperReturned = tdtmClass.handleAfterInsert(newList, dmlWrapper);
        Test.stopTest();

        System.assertEquals(
            true,
            tdtmClass.isAfterInsertRecursion(),
            'After insert recursion for should be active for AFFL_MultiRecordType_TDTM.'
        );

        System.assertEquals(true, dmlWrapperReturned.objectsToInsert.isEmpty(), 'The DMLWrapper should be empty.');
    }

    /**
     * @description Tests handleAfterInsert only sets after insert recursion on a null new list
     */
    private static void handleAfterInsertNewListNull() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        List<SObject> newList = null;
        tdtmClass.setAfterInsertRecursion();

        Test.startTest();
        TDTM_Runnable.DMLWrapper dmlWrapperReturned = tdtmClass.handleAfterInsert(newList, dmlWrapper);
        Test.stopTest();

        System.assertEquals(true, dmlWrapperReturned.objectsToInsert.isEmpty(), 'The DMLWrapper should be empty.');
    }

    /**
     * @description Tests handleAfterInsert does nothing on an after insert recursion
     */
    private static void handleAfterInsertNewListAfterInsertRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        List<SObject> newList = null;

        Test.startTest();
        TDTM_Runnable.DMLWrapper dmlWrapperReturned = tdtmClass.handleAfterInsert(newList, dmlWrapper);
        Test.stopTest();

        System.assertEquals(
            false,
            tdtmClass.isAfterInsertRecursion(),
            'After insert recursion for should be inactive for AFFL_MultiRecordType_TDTM.'
        );

        System.assertEquals(true, dmlWrapperReturned.objectsToInsert.isEmpty(), 'The DMLWrapper should be empty.');
    }

    /****************************************
     * processAfflDeletedValid
     ****************************************/

    /**
     * @description helper class for initialization of tests for processAfflDeleted
     */
    private class ProcessAfflDeletedValidData {
        public AFFL_MultiRecordType_TDTM tdtmClass;
        public TDTM_Runnable.DmlWrapper dmlWrapper;
        public Id fakeAccountId;
        public String primaryAffiliationFieldAPIName;
        public Contact testContact;
        public Affiliation__c affiliation;

        public ProcessAfflDeletedValidData() {
            this.tdtmClass = new AFFL_MultiRecordType_TDTM();
            this.dmlWrapper = new TDTM_Runnable.DmlWrapper();
            this.primaryAffiliationFieldAPIName = AffiliationTestSetupFactory_TEST.getBusinessOrganizationFieldApiName();
            this.fakeAccountId = UTIL_UnitTestData_TEST.getFakeId(Account.SObjectType);

            Id fakeContactId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
            this.testContact = new Contact(Id = fakeContactId, FirstName = 'Test');
            testContact.put(this.primaryAffiliationFieldAPIName, fakeAccountId);

            this.affiliation = new Affiliation__c(
                Account__c = fakeAccountId,
                Contact__c = fakeContactId,
                Primary__c = true
            );
        }
    }

    /**
     * @description Tests processAfflDeleted appropriately clears the primary affiliation field
     */
    private static void processAfflDeletedValid() {
        ProcessAfflDeletedValidData testData = new ProcessAfflDeletedValidData();

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.processAfflDeleted(
            testData.affiliation,
            testData.testContact,
            testData.primaryAffiliationFieldAPIName,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            contactReturned.get(testData.primaryAffiliationFieldAPIName),
            'Contact Primary Affiliation Field api name should be set to null on deletion.'
        );
        System.assertEquals(
            true,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'The Contact should be added to the DMLWrapper.'
        );
    }

    /**
     * @description Tests processAfflDeleted does not run on recursion
     */
    private static void processAfflDeletedRecursion() {
        ProcessAfflDeletedValidData testData = new ProcessAfflDeletedValidData();

        TDTM_ProcessControl.setRecursionFlag(
            TDTM_ProcessControl.registeredTrigger.CON_PrimaryAffls_TDTM_keyAfflLookupUpdated,
            true
        );

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.processAfflDeleted(
            testData.affiliation,
            testData.testContact,
            testData.primaryAffiliationFieldAPIName,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(null, contactReturned, 'Method should make no changes to the Contact on recursion.');
        System.assertEquals(
            false,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'Method should make no changes to the DMLWrapper on recursion.'
        );
    }

    /**
     * @description Tests processAfflDeleted does not run for non-primary affiliations
     */
    private static void processAfflDeletedNonPrimaryAffiliation() {
        ProcessAfflDeletedValidData testData = new ProcessAfflDeletedValidData();
        testData.affiliation.Primary__c = false;

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.processAfflDeleted(
            testData.affiliation,
            testData.testContact,
            testData.primaryAffiliationFieldAPIName,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            contactReturned,
            'Method should make no changes to the Contact on non-primary affiliations.'
        );
        System.assertEquals(
            false,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'Method should make no changes to the DMLWrapper on non-primary affiliations.'
        );
    }

    /**
     * @description Tests processAfflDeleted does not run for contacts when a primary affiliation field is not supplied
     */
    private static void processAfflDeletedNullAffiliationField() {
        ProcessAfflDeletedValidData testData = new ProcessAfflDeletedValidData();
        testData.primaryAffiliationFieldAPIName = null;

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.processAfflDeleted(
            testData.affiliation,
            testData.testContact,
            testData.primaryAffiliationFieldAPIName,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            contactReturned,
            'Method should make no changes to the Contact on a null primary affiliation field.'
        );
        System.assertEquals(
            false,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'Method should make no changes to the DMLWrapper on a null primary affiliation field.'
        );
    }

    /**
     * @description Tests processAfflDeleted does not run for contacts when the contact is null
     */
    private static void processAfflDeletedNullContact() {
        ProcessAfflDeletedValidData testData = new ProcessAfflDeletedValidData();

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.processAfflDeleted(
            testData.affiliation,
            null,
            testData.primaryAffiliationFieldAPIName,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(null, contactReturned, 'Method should make no changes to the Contact on a null contact.');
        System.assertEquals(
            false,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'Method should make no changes to the DMLWrapper on a null contact.'
        );
    }

    /**
     * @description Tests processAfflDeleted does not run for contacts when the affiliation account does not match the contact account
     */
    private static void processAfflDeletedDifferentContactPrimaryAffiliationAccount() {
        ProcessAfflDeletedValidData testData = new ProcessAfflDeletedValidData();
        Id differentFakeAccountId = UTIL_UnitTestData_TEST.getFakeId(Account.SObjectType);
        testData.affiliation = new Affiliation__c(
            Account__c = differentFakeAccountId,
            Contact__c = testData.testContact.Id,
            Primary__c = true
        );

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.processAfflDeleted(
            testData.affiliation,
            testData.testContact,
            testData.primaryAffiliationFieldAPIName,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            contactReturned,
            'Method should make no changes to the Contact on an unmatched account.'
        );
        System.assertEquals(
            false,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'Method should make no changes to the DMLWrapper on an unmatched account.'
        );
    }

    /****************************************
     * queryAfflLookupFields
     ****************************************/

    /**
     * @description Tests queryAfflLookupFields for multiple affiliations
     */
    private static void queryAfflLookupFields() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        //Setup Accounts
        Id businessOrganizationRecordTypeId = UTIL_Describe.getBizAccRecTypeID();
        Id householdAccountId = UTIL_Describe.getCustomHHAccRecTypeID();

        List<Account> businessOrganizationAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            AFFL_MultiRecordType_TEST.numberOfTestRecords,
            businessOrganizationRecordTypeId
        );
        List<Account> householdAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            AFFL_MultiRecordType_TEST.numberOfTestRecords,
            householdAccountId
        );

        List<Account> accountsToInsert = new List<Account>();
        accountsToInsert.addAll(businessOrganizationAccounts);
        accountsToInsert.addAll(householdAccounts);
        //Saving time on the dml operation adds up
        insert accountsToInsert;

        //Setup Contacts
        List<Contact> contactList = UTIL_UnitTestData_TEST.getMultipleTestContacts(
            AFFL_MultiRecordType_TEST.numberOfTestRecords
        );

        for (Integer i = 0; i < AFFL_MultiRecordType_TEST.numberOfTestRecords; i++) {
            Contact contactToInsert = contactList[i];
            contactToInsert.Primary_Household__c = householdAccounts[i].Id;
            contactToInsert.Primary_Organization__c = businessOrganizationAccounts[i].Id;
        }

        insert contactList;
        Map<Id, Contact> insertedContactsByIds = new Map<Id, Contact>(contactList);

        //Mock Affiliations
        List<Affiliation__c> affiliationList = new List<Affiliation__c>();

        for (Integer i = 0; i < AFFL_MultiRecordType_TEST.numberOfTestRecords; i++) {
            Affiliation__c businessAffiliation = new Affiliation__c(
                Contact__c = contactList[i].Id,
                Account__c = businessOrganizationAccounts[i].Id,
                Primary__c = true
            );
            affiliationList.add(businessAffiliation);

            Affiliation__c householdAffiliation = new Affiliation__c(
                Contact__c = contactList[i].Id,
                Account__c = householdAccounts[i].Id,
                Primary__c = true
            );
            affiliationList.add(householdAffiliation);
        }

        List<SObject> affiliationAsSObjectList = affiliationList;

        //Set up affiliation mappings on household and business organization
        //This is done later to cause it not to interfere with our data setup so the unit test detects unexpected behavior better.
        AffiliationTestSetupFactory_TEST.setupMappingsByDevNameAndApiName(false);

        Test.startTest();
        Map<Id, Contact> returnedContactsByIds = tdtmClass.queryAfflLookupFields(affiliationAsSObjectList);
        Test.stopTest();

        System.assertEquals(
            insertedContactsByIds.size(),
            returnedContactsByIds.size(),
            'Number of returned contacts should match the number inserted.'
        );

        for (Contact returnedContact : returnedContactsByIds.values()) {
            Contact insertedContact = insertedContactsByIds.get(returnedContact.Id);

            System.assertNotEquals(null, insertedContact, 'A contact should be returned for each inserted contact.');
            System.assertEquals(
                returnedContact.Primary_Household__c,
                insertedContact.Primary_Household__c,
                'The Primary Household field should be queried and match that of the inserted Contact.'
            );
            System.assertEquals(
                returnedContact.Primary_Organization__c,
                insertedContact.Primary_Organization__c,
                'The Primary Organization field should be queried and match that of the inserted Contact.'
            );
        }
    }

    /****************************************
     * populateKeyAffls
     ****************************************/

    /**
     * @description helper class for initialization of tests for populateKeyAffls
     */
    private class PopulateKeyAfflsValidData {
        public AFFL_MultiRecordType_TDTM tdtmClass;
        public TDTM_Runnable.DmlWrapper dmlWrapper;
        public Id fakeAccountId;
        public String primaryAffiliationFieldAPIName;
        public Contact testContact;
        public Affiliation__c affiliation;

        public PopulateKeyAfflsValidData() {
            this.tdtmClass = new AFFL_MultiRecordType_TDTM();
            this.dmlWrapper = new TDTM_Runnable.DmlWrapper();
            this.primaryAffiliationFieldAPIName = AffiliationTestSetupFactory_TEST.getBusinessOrganizationFieldApiName();
            this.fakeAccountId = UTIL_UnitTestData_TEST.getFakeId(Account.SObjectType);

            Id fakeContactId = UTIL_UnitTestData_TEST.getFakeId(Contact.SObjectType);
            this.testContact = new Contact(Id = fakeContactId, FirstName = 'Test');
            testContact.put(this.primaryAffiliationFieldAPIName, fakeAccountId);

            this.affiliation = new Affiliation__c(
                Account__c = fakeAccountId,
                Contact__c = fakeContactId,
                Primary__c = true
            );
        }
    }

    /**
     * @description Tests populateKeyAffls appropriately sets the primary affiliation field
     */
    private static void populateKeyAfflsValid() {
        PopulateKeyAfflsValidData testData = new PopulateKeyAfflsValidData();

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.populateKeyAffls(
            testData.affiliation,
            testData.primaryAffiliationFieldAPIName,
            testData.testContact,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            testData.affiliation.Account__c,
            (Id) contactReturned.get(testData.primaryAffiliationFieldAPIName),
            'Contact Primary Affiliation Field api name should be set to the Affiliation\'s Account.'
        );
        System.assertEquals(
            true,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'The Contact should be added to the DMLWrapper.'
        );
    }

    /**
     * @description Tests populateKeyAffls does not run on recursion
     */
    private static void populateKeyAfflsRecursion() {
        PopulateKeyAfflsValidData testData = new PopulateKeyAfflsValidData();

        TDTM_ProcessControl.setRecursionFlag(
            TDTM_ProcessControl.registeredTrigger.CON_PrimaryAffls_TDTM_keyAfflLookupUpdated,
            true
        );

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.populateKeyAffls(
            testData.affiliation,
            testData.primaryAffiliationFieldAPIName,
            testData.testContact,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(null, contactReturned, 'Method should make no changes to the Contact on recursion.');
        System.assertEquals(
            false,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'Method should make no changes to the DMLWrapper on recursion.'
        );
    }

    /**
     * @description Tests populateKeyAffls does not run for contacts when a primary affiliation field is not supplied
     */
    private static void populateKeyAfflsNullAffiliationField() {
        PopulateKeyAfflsValidData testData = new PopulateKeyAfflsValidData();
        testData.primaryAffiliationFieldAPIName = null;

        Test.startTest();
        Contact contactReturned = testData.tdtmClass.populateKeyAffls(
            testData.affiliation,
            testData.primaryAffiliationFieldAPIName,
            testData.testContact,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            contactReturned,
            'Method should make no changes to the Contact on a null primary affiliation field.'
        );
        System.assertEquals(
            false,
            testData.dmlWrapper.objectsToUpdate.contains(contactReturned),
            'Method should make no changes to the DMLWrapper on a null primary affiliation field.'
        );
    }

    /****************************************
     * uncheckOtherPrimariesSameType
     ****************************************/

    /**
     * @description Tests uncheckOtherPrimariesSameType for multiple affiliations
     */
    private static void uncheckOtherPrimariesSameType() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        //Setup Accounts
        Id businessOrganizationRecordTypeId = UTIL_Describe.getBizAccRecTypeID();
        Id householdAccountId = UTIL_Describe.getCustomHHAccRecTypeID();

        List<Account> businessOrganizationAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            AFFL_MultiRecordType_TEST.numberOfTestRecords,
            businessOrganizationRecordTypeId
        );
        List<Account> householdAccounts = UTIL_UnitTestData_TEST.getMultipleTestAccounts(
            AFFL_MultiRecordType_TEST.numberOfTestRecords,
            householdAccountId
        );

        List<Account> accountsToInsert = new List<Account>();
        accountsToInsert.addAll(businessOrganizationAccounts);
        accountsToInsert.addAll(householdAccounts);
        //Saving time on the dml operation adds up
        insert accountsToInsert;

        //Setup Contacts
        List<Contact> contactList = UTIL_UnitTestData_TEST.getMultipleTestContacts(
            AFFL_MultiRecordType_TEST.numberOfTestRecords
        );

        for (Integer i = 0; i < AFFL_MultiRecordType_TEST.numberOfTestRecords; i++) {
            Contact contactToInsert = contactList[i];
            contactToInsert.Primary_Household__c = householdAccounts[i].Id;
            contactToInsert.Primary_Organization__c = businessOrganizationAccounts[i].Id;
        }

        insert contactList;
        Map<Id, Contact> insertedContactsByIds = new Map<Id, Contact>(contactList);

        //Setup Initial Primary Affiliations
        List<Affiliation__c> oldPrimaryAffiliationList = new List<Affiliation__c>();

        for (Integer i = 0; i < AFFL_MultiRecordType_TEST.numberOfTestRecords; i++) {
            Affiliation__c businessAffiliation = new Affiliation__c(
                Contact__c = contactList[i].Id,
                Account__c = businessOrganizationAccounts[i].Id,
                Primary__c = true
            );
            oldPrimaryAffiliationList.add(businessAffiliation);

            Affiliation__c householdAffiliation = new Affiliation__c(
                Contact__c = contactList[i].Id,
                Account__c = householdAccounts[i].Id,
                Primary__c = true
            );
            oldPrimaryAffiliationList.add(householdAffiliation);
        }
        insert oldPrimaryAffiliationList;
        Map<Id, Affiliation__c> oldPrimaryAffiliationsById = new Map<Id, Affiliation__c>(oldPrimaryAffiliationList);

        //Setup new primary affiliations
        List<Affiliation__c> newPrimaryAffiliationList = new List<Affiliation__c>();

        for (Integer i = 0; i < AFFL_MultiRecordType_TEST.numberOfTestRecords; i++) {
            Integer nextSafeInteger = math.mod(i, 5);
            Affiliation__c businessAffiliation = new Affiliation__c(
                Contact__c = contactList[i].Id,
                Account__c = businessOrganizationAccounts[nextSafeInteger].Id,
                Primary__c = true
            );
            newPrimaryAffiliationList.add(businessAffiliation);

            Affiliation__c householdAffiliation = new Affiliation__c(
                Contact__c = contactList[i].Id,
                Account__c = householdAccounts[nextSafeInteger].Id,
                Primary__c = true
            );
            newPrimaryAffiliationList.add(householdAffiliation);
        }
        //Recalculate formulas in memory!
        Formula.recalculateFormulas(newPrimaryAffiliationList);

        Test.startTest();
        List<Affiliation__c> uncheckedAffiliations = tdtmClass.uncheckOtherPrimariesSameType(
            newPrimaryAffiliationList,
            dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            oldPrimaryAffiliationList.size(),
            uncheckedAffiliations.size(),
            'Number of returned affiliations should match the number unchecked.'
        );

        for (Affiliation__c uncheckedAffiliation : uncheckedAffiliations) {
            Affiliation__c originalAffiliation = oldPrimaryAffiliationsById.get(uncheckedAffiliation.Id);
            System.assertNotEquals(null, originalAffiliation, 'Each old primary affiliation should be modified.');
            System.assertEquals(
                false,
                originalAffiliation.Primary__c,
                'Each old primary affiliation should have its Primary field set to false.'
            );
        }
    }

    /****************************************
     * createProgramEnrollmentIfNecessary
     ****************************************/

    /**
     * @description helper class for initialization of tests for createProgramEnrollmentIfNecessary
     */
    private class CreateProgramEnrollmentValidData {
        public AFFL_MultiRecordType_TDTM tdtmClass;
        public TDTM_Runnable.DmlWrapper dmlWrapper;
        public Account accountToTest;
        public Contact contactToTest;
        public Affiliation__c affiliation;

        public CreateProgramEnrollmentValidData() {
            this.tdtmClass = new AFFL_MultiRecordType_TDTM();
            this.dmlWrapper = new TDTM_Runnable.DmlWrapper();
            this.contactToTest = UTIL_UnitTestData_TEST.getUniqueContact(1);
            insert contactToTest;

            Id businessOrganizationRecordTypeId = UTIL_Describe.getBizAccRecTypeID();
            this.accountToTest = UTIL_UnitTestData_TEST.getMultipleTestAccounts(1, businessOrganizationRecordTypeId)[0];
            insert this.accountToTest;

            this.affiliation = new Affiliation__c(
                Id = UTIL_UnitTestData_TEST.getFakeId(Affiliation__c.SObjectType),
                Account__c = this.accountToTest.Id,
                Contact__c = this.contactToTest.Id,
                Primary__c = true
            );
        }
    }

    /**
     * @description Tests createProgramEnrollmentIfNecessary for valid data requiring a program enrollment be created
     */
    private static void createProgramEnrollmentIfNecessaryValidData() {
        CreateProgramEnrollmentValidData testData = new CreateProgramEnrollmentValidData();
        AFFL_MultiRecordType_TDTM.afflMapper = new AFFL_MultiRecordTypeMapper_STUB(true);
        Formula.recalculateFormulas(new List<Affiliation__c>{ testData.affiliation });

        Test.startTest();
        Program_Enrollment__c programEnrollmentCreated = testData.tdtmClass.createProgramEnrollmentIfNecessary(
            testData.affiliation,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertNotEquals(
            null,
            programEnrollmentCreated,
            'A Program Enrollment should be created for the associated Affiliation.'
        );
        System.assertEquals(
            testData.affiliation.Id,
            programEnrollmentCreated.Affiliation__c,
            'The Program Enrollment\'s Affiliation should match the provided Affiliation\'s.'
        );
        System.assertEquals(
            testData.affiliation.Account__c,
            programEnrollmentCreated.Account__c,
            'The Program Enrollment\'s Account should match the Affiliation\'s.'
        );
        System.assertEquals(
            testData.affiliation.Contact__c,
            programEnrollmentCreated.Contact__c,
            'The Program Enrollment\'s Contact should match the Affiliation\'s.'
        );
    }

    /**
     * @description Tests createProgramEnrollmentIfNecessary for when a Program Enrollment is not needed
     */
    private static void createProgramEnrollmentIfNecessaryNotNeeded() {
        CreateProgramEnrollmentValidData testData = new CreateProgramEnrollmentValidData();
        AFFL_MultiRecordType_TDTM.afflMapper = new AFFL_MultiRecordTypeMapper_STUB(false);
        Formula.recalculateFormulas(new List<Affiliation__c>{ testData.affiliation });

        Test.startTest();
        Program_Enrollment__c programEnrollmentCreated = testData.tdtmClass.createProgramEnrollmentIfNecessary(
            testData.affiliation,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            programEnrollmentCreated,
            'A Program Enrollment should not be created when the mapper specifies it should not.'
        );
    }

    /**
     * @description Tests createProgramEnrollmentIfNecessary for when the affiliation type is null
     */
    private static void createProgramEnrollmentIfNecessaryNoAffiliationType() {
        CreateProgramEnrollmentValidData testData = new CreateProgramEnrollmentValidData();
        AFFL_MultiRecordType_TDTM.afflMapper = new AFFL_MultiRecordTypeMapper_STUB(true);

        Test.startTest();
        Program_Enrollment__c programEnrollmentCreated = testData.tdtmClass.createProgramEnrollmentIfNecessary(
            testData.affiliation,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            programEnrollmentCreated,
            'A Program Enrollment should not be created when the affiliation type is null.'
        );
    }

    /**
     * @description Tests createProgramEnrollmentIfNecessary for when the affiliation is null
     */
    private static void createProgramEnrollmentIfNecessaryNullAffiliation() {
        CreateProgramEnrollmentValidData testData = new CreateProgramEnrollmentValidData();
        AFFL_MultiRecordType_TDTM.afflMapper = new AFFL_MultiRecordTypeMapper_STUB(true);

        Test.startTest();
        Program_Enrollment__c programEnrollmentCreated = testData.tdtmClass.createProgramEnrollmentIfNecessary(
            null,
            testData.dmlWrapper
        );
        Test.stopTest();

        System.assertEquals(
            null,
            programEnrollmentCreated,
            'A Program Enrollment should not be created when the affiliation type is null.'
        );
    }

    /****************************************
     * RECURSION TESTS
     ****************************************/

    /**
     * @description Tests setBeforeInsertRecursion
     */
    @isTest
    static void setBeforeInsertRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        Test.startTest();
        tdtmClass.setBeforeInsertRecursion();
        Test.stopTest();

        Boolean beforeInsert = TDTM_ProcessControl.getRecursionFlag(BEFORE_INSERT_RECURSION);

        System.assertEquals(
            true,
            beforeInsert,
            'Before Insert recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests isBeforeInsertRecursion
     */
    @isTest
    static void isBeforeInsertRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        tdtmClass.setBeforeInsertRecursion();

        Test.startTest();
        Boolean beforeInsert = tdtmClass.isBeforeInsertRecursion();
        Test.stopTest();

        System.assertEquals(
            true,
            beforeInsert,
            'Before Insert recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests unsetBeforeInsertRecursion
     */
    @isTest
    static void unsetBeforeInsertRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        tdtmClass.setBeforeInsertRecursion();

        Test.startTest();
        tdtmClass.unsetBeforeInsertRecursion();
        Test.stopTest();

        Boolean beforeInsert = tdtmClass.isBeforeInsertRecursion();

        System.assertEquals(
            false,
            beforeInsert,
            'Before Insert recursion flag should be inactive for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests setAfterInsertRecursion
     */
    @isTest
    static void setAfterInsertRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        Test.startTest();
        tdtmClass.setAfterInsertRecursion();
        Test.stopTest();

        Boolean afterInsert = TDTM_ProcessControl.getRecursionFlag(AFTER_INSERT_RECURSION);

        System.assertEquals(
            true,
            afterInsert,
            'After Insert recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests isAfterInsertRecursion
     */
    @isTest
    static void isAfterInsertRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        tdtmClass.setAfterInsertRecursion();

        Test.startTest();
        Boolean afterInsert = tdtmClass.isAfterInsertRecursion();
        Test.stopTest();

        System.assertEquals(
            true,
            afterInsert,
            'After Insert recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests unsetAfterInsertRecursion
     */
    @isTest
    static void unsetAfterInsertRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        tdtmClass.setAfterInsertRecursion();

        Test.startTest();
        tdtmClass.unsetAfterInsertRecursion();
        Test.stopTest();

        Boolean afterInsert = tdtmClass.isAfterInsertRecursion();

        System.assertEquals(
            false,
            afterInsert,
            'After Insert recursion flag should be inactive for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests setAfterUpdateRecursion
     */
    @isTest
    static void setAfterUpdateRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        Test.startTest();
        tdtmClass.setAfterUpdateRecursion();
        Test.stopTest();

        Boolean afterUpdate = TDTM_ProcessControl.getRecursionFlag(AFTER_UPDATE_RECURSION);

        System.assertEquals(
            true,
            afterUpdate,
            'After Update recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests isAfterUpdateRecursion
     */
    @isTest
    static void isAfterUpdateRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        tdtmClass.setAfterUpdateRecursion();

        Test.startTest();
        Boolean afterUpdate = tdtmClass.isAfterUpdateRecursion();
        Test.stopTest();

        System.assertEquals(
            true,
            afterUpdate,
            'After Update recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests unsetAfterUpdateRecursion
     */
    @isTest
    static void unsetAfterUpdateRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        tdtmClass.setAfterUpdateRecursion();

        Test.startTest();
        tdtmClass.unsetAfterUpdateRecursion();
        Test.stopTest();

        Boolean afterUpdate = tdtmClass.isAfterUpdateRecursion();

        System.assertEquals(
            false,
            afterUpdate,
            'After Update recursion flag should be inactive for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests setAffiliationMadePrimaryRecursion
     */
    @isTest
    static void setAffiliationMadePrimaryRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        Test.startTest();
        tdtmClass.setAffiliationMadePrimaryRecursion();
        Test.stopTest();

        Boolean affiliationMadePrimary = TDTM_ProcessControl.getRecursionFlag(AFFILIATION_MADE_PRIMARY_RECURSION);

        System.assertEquals(
            true,
            affiliationMadePrimary,
            'Affiliation Made Primary recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests isAffiliationMadePrimaryRecursion
     */
    @isTest
    static void isAffiliationMadePrimaryRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        tdtmClass.setAffiliationMadePrimaryRecursion();

        Test.startTest();
        Boolean affiliationMadePrimary = tdtmClass.isAffiliationMadePrimaryRecursion();
        Test.stopTest();

        System.assertEquals(
            true,
            affiliationMadePrimary,
            'Affiliation Made Primary recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests resetAffiliationMadePrimaryRecursion
     */
    @isTest
    static void resetAffiliationMadePrimaryRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();

        tdtmClass.setAffiliationMadePrimaryRecursion();

        Test.startTest();
        tdtmClass.resetAffiliationMadePrimaryRecursion();
        Test.stopTest();

        Boolean affiliationMadePrimary = tdtmClass.isAffiliationMadePrimaryRecursion();

        System.assertEquals(
            false,
            affiliationMadePrimary,
            'Affiliation Made Primary recursion flag should be inactive for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**
     * @description Tests isContactPrimaryAffiliationUpdatedRecursion
     */
    @isTest
    static void isContactPrimaryAffiliationUpdatedRecursion() {
        AFFL_MultiRecordType_TDTM tdtmClass = new AFFL_MultiRecordType_TDTM();
        TDTM_ProcessControl.setRecursionFlag(CONTACT_PRIMARY_AFFILIATION_UPDATED_RECURSION, true);

        Test.startTest();
        Boolean contactPrimaryAffiliationUpdatedRecursion = tdtmClass.isContactPrimaryAffiliationUpdatedRecursion();
        Test.stopTest();

        System.assertEquals(
            true,
            contactPrimaryAffiliationUpdatedRecursion,
            'Contact Primary Affiliation Updated recursion flag should be active for AFFL_MultiRecordType_TDTM.'
        );
    }

    /**************************************************************************
     * STUBS
     **************************************************************************/

    /**
     * @description Stubs the AFFL_MultiRecordTypeMapper to mock behavior of needsProgramEnrollment
     */
    public class AFFL_MultiRecordTypeMapper_STUB extends AFFL_MultiRecordTypeMapper {
        Boolean programEnrollmentNeeded;

        public AFFL_MultiRecordTypeMapper_STUB(Boolean programEnrollmentNeeded) {
            this.programEnrollmentNeeded = programEnrollmentNeeded;
        }

        public override Boolean needsProgramEnrollment(Affiliation__c affl) {
            return programEnrollmentNeeded;
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
* @group-content ../../ApexDocContent/Tests.htm
* @description Test class for AccountModelHealthCheckVMapper.
*/
@isTest
public with sharing class AccountModelHealthCheckVMapper_TEST {
    /**************************************************************************************************************************
    * @description Test method to verify that the getInstance method returns a new instance of the 
    * AccountModelHealthCheckVMapper class when one does not already exist.
    ***************************************************************************************************************************/
    @isTest
    private static void getInstanceNew() {

        Test.startTest();
            AccountModelHealthCheckVMapper accountModelHealthCheckVMapperInstance = AccountModelHealthCheckVMapper.getInstance();
        Test.stopTest();

        System.assertEquals(AccountModelHealthCheckVMapper.instance, accountModelHealthCheckVMapperInstance, 'Instance of mapper class returned should match static instance variable.');
        System.assertEquals(true, accountModelHealthCheckVMapperInstance != null, 'Instance of mapper class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that the getInstance method returns the existing instance of the 
    * AccountModelHealthCheckVMapper class when one already exists.
    ***************************************************************************************************************************/
    @isTest
    private static void getInstanceExisting() {

        Test.startTest();
            AccountModelHealthCheckVMapper accountModelHealthCheckVMapperInstance1 = AccountModelHealthCheckVMapper.getInstance();
            AccountModelHealthCheckVMapper accountModelHealthCheckVMapperInstance2 = AccountModelHealthCheckVMapper.getInstance();
        Test.stopTest();

        System.assertEquals(AccountModelHealthCheckVMapper.instance, accountModelHealthCheckVMapperInstance1, 'Instance of mapper class returned should match static instance variable.');
        System.assertEquals(accountModelHealthCheckVMapperInstance1, accountModelHealthCheckVMapperInstance2, 'Subsequent retrievals of mapper class instance should return existing instance.');
        System.assertEquals(true, accountModelHealthCheckVMapperInstance1 != null, 'Instance of mapper class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locateRecordTypeService() returns an instance of the RecordTypeService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locateRecordTypeServiceValid(){
        Test.startTest();
        RecordTypeService rtServiceInstance = AccountModelHealthCheckVMapper.getInstance().locateRecordTypeService();
        Test.stopTest();

        System.assertEquals(RecordTypeService.getInstance(), rtServiceInstance, 'Should return instance of RecordTypeService class.');
        System.assertEquals(true, rtServiceInstance != null, 'Instance of RecordTypeService class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locateAccountModelSettingsService() returns an instance of the AccountModelSettingsService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locateAccountModelSettingsServiceValid(){
        Test.startTest();
        AccountModelSettingsService accModSettingsServiceInstance = AccountModelHealthCheckVMapper.getInstance().locateAccountModelSettingsService();
        Test.stopTest();

        System.assertEquals(AccountModelSettingsService.getInstance(), accModSettingsServiceInstance, 'Should return instance of AccountModelSettingsService class.');
        System.assertEquals(true, accModSettingsServiceInstance != null, 'Instance of AccountModelSettingsService class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locateStringHandlingService() returns an instance of the StringHandlingService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locateStringHandlingServiceValid(){
        Test.startTest();
        StringHandlingService stringHandlingServiceInstance = AccountModelHealthCheckVMapper.getInstance().locateStringHandlingService();
        Test.stopTest();

        System.assertEquals(StringHandlingService.getInstance(), stringHandlingServiceInstance, 'Should return instance of StringHandlingService class.');
        System.assertEquals(true, stringHandlingServiceInstance != null, 'Instance of StringHandlingService class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify combineAccountHealthCheckGroupViewModels() returns a combined HealthCheckGroupVModel comprised of
    * the combined properties of the group view models passed as arguments.
    **************************************************************************************************************************/ 
    @isTest 
    private static void combineAccountHealthCheckGroupViewModelsValid(){

        List<HealthCheckGroupVModel> testHealthCheckGroupModelsList = new List<HealthCheckGroupVModel>();
        List<HealthCheckItemVModel> group1HealthCheckItemList = new List<HealthCheckItemVModel>();

        group1HealthCheckItemList.add(new HealthCheckItemVModel('Key1',
                                                            'Setting-X',
                                                            'Pass',
                                                            'PassedLabel',
                                                            'Description',
                                                            'RecommendedFix',
                                                            new List<HealthCheckItemVModel>()));
                                                            
        group1HealthCheckItemList.add(new HealthCheckItemVModel('Key2',
                                                            'Setting-B',
                                                            'Pass',
                                                            'PassedLabel',
                                                            'Description',
                                                            'RecommendedFix',
                                                            new List<HealthCheckItemVModel>()));

        group1HealthCheckItemList.add(new HealthCheckItemVModel('Key3',
                                                            'Setting-Y',
                                                            'Fail',
                                                            'FailedLabel',
                                                            'Description',
                                                            'RecommendedFix',
                                                            new List<HealthCheckItemVModel>()));


        testHealthCheckGroupModelsList.add(new HealthCheckGroupVModel('SubGroup1',
                                                                 'Fail',
                                                                 2,
                                                                 3,
                                                                 new List<String>(),
                                                                 group1HealthCheckItemList));

        testHealthCheckGroupModelsList.add(new HealthCheckGroupVModel('SubGroup2',
                                                                 'Pass',
                                                                 1,
                                                                 1,
                                                                 new List<String>(),
                                                                 new List<HealthCheckItemVModel>()));


        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = AccountModelHealthCheckVMapper.getInstance().combineAccountHealthCheckGroupViewModels(testHealthCheckGroupModelsList);
        Test.stopTest();

        System.assertEquals(Label.stgHealthCheckAccountModel, healthCheckGroupVModel.label, 'Group label should be \'' + Label.stgHealthCheckAccountModel + '\'');
        System.assertEquals(Label.stgHealthCheckStatusFailed, healthCheckGroupVModel.status, 'Group status should be \'' + Label.stgHealthCheckStatusFailed + '\'');
        System.assertEquals(3, healthCheckGroupVModel.passedChecks, 'Group passed checks should be \'' + healthCheckGroupVModel.passedChecks + '\'');
        System.assertEquals(4, healthCheckGroupVModel.totalChecks, 'Group total checks should be \'' + healthCheckGroupVModel.totalChecks + '\'');
        System.assertEquals(3, healthCheckGroupVModel.healthCheckItemList.size(), 'Group HealthCheckItems list should have \'' + healthCheckGroupVModel.healthCheckItemList.size() + '\' items');

        System.assertEquals('Setting-Y', healthCheckGroupVModel.healthCheckItemList[0].setting, 'HealthCheckItemList should be sorted alphabetically by Setting, with Failed items prioritized.');
        System.assertEquals('Setting-B', healthCheckGroupVModel.healthCheckItemList[1].setting, 'HealthCheckItemList should be sorted alphabetically by Setting, with Failed items prioritized.');
        System.assertEquals('Setting-X', healthCheckGroupVModel.healthCheckItemList[2].setting, 'HealthCheckItemList should be sorted alphabetically by Setting, with Failed items prioritized.');
    }

    /**************************************************************************************************************************
    * @description Test to verify getDefaultAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the defaultAccountModel Id in AccountSettingsModel is valid and matches to a RT for Default 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getDefaultAccountModelHealthCheckItemsIdMatchFoundToRTValidAndActive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidAndActiveDefaultModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                '000000000000000002',
                                                                                '000000000000000003');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000001',
                                                              'Test Record Name',
                                                              'testRecordDevName',
                                                              true);
                          
        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getDefaultAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusPassed,
                                                                                   1,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeValid, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        String expectedFix = Label.stgHealthCheckFixNotApplicable;

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccModelTitle, 
                                                                                'Pass', 
                                                                                Label.stgHealthCheckStatusPassed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getDefaultAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when the ID provided as the defaultAccountModel Id in AccountSettingsModel is valid and matches to a RT for Default 
    * Account Modelthat is valid, but inactive.
    **************************************************************************************************************************/ 
    @isTest
    private static void getDefaultAccountModelHealthCheckItemsIdMatchFoundToRTValidAndInactive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidAndInactiveDefaultModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                            '000000000000000002',
                                                                                            '000000000000000003');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000001',
                                                              'Test Record Name',
                                                              'testRecordDevName',
                                                              false);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getDefaultAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeInactive, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelDefaultInactiveFix, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccModelTitle, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getDefaultAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when an the ID provided as the defaultAccountModel Id in AccountSettingsModel is not an ID.
    **************************************************************************************************************************/ 
    @isTest
    private static void getDefaultAccountModelHealthCheckItemsInvalidDefaultId(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNullModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('Not an ID default acct',
                                                                                            'Not an ID admin acct',
                                                                                            'Not an Id HH acct');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000111',
                                                              'Account Name',
                                                              'accountDevName',
                                                              true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getDefaultAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{'Not an ID default acct'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelDefaultNotFoundFix, 
            new List<Object>{'Not an ID default acct'}
        );

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccModelTitle, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getDefaultAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when an invalid RT is specified for Default Account Model and the defaultAccountModel Id in AccountSettingsModel is a
    * valid ID, but does not match any Ids in the RecordType map.
    **************************************************************************************************************************/ 
    @isTest
    private static void getDefaultAccountModelHealthCheckItemsValidIdNoMatchingRT(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNullModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000000',
                                                                                            '000000000000000000',
                                                                                            '000000000000000000');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000123',
                                                              'Different Account Name',
                                                              'differentAccountDevName',
                                                              true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getDefaultAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{'000000000000000000'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelDefaultNotFoundFix, 
            new List<Object>{'000000000000000000'}
        );

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccModelTitle, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getAdministrativeAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the administrative AccountModel Id in AccountSettingsModel is valid and matches to a RT for Admin 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getAdministrativeAccountModelHealthCheckItemsIdMatchFoundToRTValidAndActive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidAndActiveDefaultModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                            '000000000000000002',
                                                                                            '000000000000000003');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000002',
                                                              'Test Record Name',
                                                              'testRecordDevName',
                                                              true);
                          
        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getAdministrativeAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusPassed,
                                                                                   1,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeValid, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        String expectedFix = Label.stgHealthCheckFixNotApplicable;
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAdminAccountRecordType, 
                                                                                'Pass', 
                                                                                Label.stgHealthCheckStatusPassed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getAdministrativeAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when the ID provided as the administrativeAccountModel Id in AccountSettingsModel is valid and matches to a RT for Admin 
    * Account Modelthat is valid, but inactive.
    **************************************************************************************************************************/ 
    @isTest
    private static void getAdministrativeAccountModelHealthCheckItemsIdMatchFoundToRTValidAndInactive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidAndInactiveDefaultModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                            '000000000000000002',
                                                                                            '000000000000000003');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000002',
                                                              'Test Record Name',
                                                              'testRecordDevName',
                                                              false);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getAdministrativeAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeInactive, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelAdminInactiveFix, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAdminAccountRecordType, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getAdministrativeAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when an the ID provided as the administrativeAccountModel Id in AccountSettingsModel is not an ID.
    **************************************************************************************************************************/ 
    @isTest
    private static void getAdministrativeAccountModelHealthCheckItemsInvalidDefaultId(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNullModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('Not an ID default acct',
                                                                                            'Not an ID admin acct',
                                                                                            'Not an Id HH acct');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000111',
                                                              'Account Name',
                                                              'accountDevName',
                                                              true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getAdministrativeAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{'Not an ID admin acct'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelAdminNotFoundFix, 
            new List<Object>{'Not an ID admin acct'}
        );
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAdminAccountRecordType, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getAdministrativeAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when an invalid RT is specified for Administrative Account Model and the adminAccountModel Id in AccountSettingsModel is a
    * valid ID, but does not match any Ids in the RecordType map.
    **************************************************************************************************************************/ 
    @isTest
    private static void getAdministrativeAccountModelHealthCheckItemsValidIdNoMatchingRT(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNullModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000000',
                                                                                            '000000000000000000',
                                                                                            '000000000000000000');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000123',
                                                              'Different Account Name',
                                                              'differentAccountDevName',
                                                              true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getAdministrativeAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{'000000000000000000'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelAdminNotFoundFix, 
            new List<Object>{'000000000000000000'}
        );
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAdminAccountRecordType, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * pass when the ID provided as the household AccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Modelthat is valid and active.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHouseholdAccountModelHealthCheckItemsIdMatchFoundToRTValidAndActive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidAndActiveDefaultModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                            '000000000000000002',
                                                                                            '000000000000000003');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000003',
                                                              'Test Record Name',
                                                              'testRecordDevName',
                                                              true);
                          
        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getHouseholdAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusPassed,
                                                                                   1,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeValid, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        String expectedFix = Label.stgHealthCheckFixNotApplicable;
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccountRecordTypeSupportsHHAddress, 
                                                                                'Pass', 
                                                                                Label.stgHealthCheckStatusPassed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when the ID provided as the householdAccountModel Id in AccountSettingsModel is valid and matches to a RT for HH 
    * Account Model that is valid, but inactive.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHouseholdAccountModelHealthCheckItemsIdMatchFoundToRTValidAndInactive(){
        RecordTypeService.instance = new STUB_RecordTypeServiceValidAndInactiveDefaultModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                            '000000000000000002',
                                                                                            '000000000000000003');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000003',
                                                              'Test HH Record Name',
                                                              'testHHRecordDevName',
                                                              false);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getHouseholdAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeInactive, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelHHInactiveFix, 
            new List<Object>{'Test Record Name', 'testRecordDevName'}
        );
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccountRecordTypeSupportsHHAddress, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when an the ID provided as the administrativeAccountModel Id in AccountSettingsModel is not an ID.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHouseholdAccountModelHealthCheckItemsInvalidDefaultId(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNullModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('Not an ID default acct',
                                                                                            'Not an ID admin acct',
                                                                                            'Not an ID HH acct');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000111',
                                                              'Account Name',
                                                              'accountDevName',
                                                              true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getHouseholdAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{'Not an ID HH acct'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelHHNotFoundFix, 
            new List<Object>{'Not an ID HH acct'}
        );
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccountRecordTypeSupportsHHAddress, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHouseholdAccountModelHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * fail when an invalid RT is specified for Administrative Account Model and the adminAccountModel Id in AccountSettingsModel is a
    * valid ID, but does not match any Ids in the RecordType map.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHouseholdAccountModelHealthCheckItemsValidIdNoMatchingRT(){
        RecordTypeService.instance = new STUB_RecordTypeServiceNullModel();

        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000000',
                                                                                            '000000000000000000',
                                                                                            '000000000000000000');

        RecordTypeModel recordTypeModel = new RecordTypeModel('000000000000000123',
                                                              'Different Account Name',
                                                              'differentAccountDevName',
                                                              true);

        Map<Id, RecordTypeModel> recordTypeModelsById = new Map<Id, RecordTypeModel>{recordTypeModel.id => recordTypeModel};

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getHouseholdAccountModelHealthCheckItems(accountModelSettingsModel, recordTypeModelsById);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCRecordTypeNotFound, 
            new List<Object>{'000000000000000000'}
        );
        String expectedFix = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAccountModelHHNotFoundFix, 
            new List<Object>{'000000000000000000'}
        );
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgAccountRecordTypeSupportsHHAddress, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getHealthCheckGroup() returns a HealthCheckGroupVModel with a status of
    * passed when valid and active record types are specified for Default, Administrative and Household Account Models and the
    * record types specified for HH and Admin accounts are unique.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHealthCheckGroupValidAndActive(){
        AccountModelSettingsService.instance = new STUB_AccountModelSettingsServiceValidDefaultAccountId();
        RecordTypeService.instance = new STUB_RecordTypeServiceForGetHealtCheckGroupValid();

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVModel = AccountModelHealthCheckVMapper.getInstance().getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHealthCheckAccountModel, 
            hlthChkGroupVModel.label, 
            'Label should be \'' + Label.stgHealthCheckAccountModel + '\''
        );
        System.assertEquals(
            Label.stgHealthCheckStatusPassed, 
            hlthChkGroupVModel.status, 
            'Status should be \'' + Label.stgHealthCheckStatusPassed + '\''
        );
        System.assertEquals(
            4, 
            hlthChkGroupVModel.healthCheckItemList.size(), 
            'Should contain Health Check Items for Default, Admin and HH Account models and Admin and HH Account Uniqueness.'
        );
    }

    /**************************************************************************************************************************
    * @description Test to verify getHealthCheckGroup() returns a HealthCheckGroupVModel with a status of
    * failed when a valid, but inactive record type is specified for Default Account Model.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHealthCheckGroupValidAndInactive(){
        AccountModelSettingsService.instance = new STUB_AccountModelSettingsServiceValidDefaultAccountId();
        RecordTypeService.instance = new STUB_RecordTypeServiceValidAndInactiveDefaultModel();

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVModel = AccountModelHealthCheckVMapper.getInstance().getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHealthCheckAccountModel, 
            hlthChkGroupVModel.label, 
            'Label should be \'' + Label.stgHealthCheckAccountModel + '\''
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed, 
            hlthChkGroupVModel.status, 
            'Status should be \'' + Label.stgHealthCheckStatusFailed + '\''
        );
        System.assertEquals(
            4, 
            hlthChkGroupVModel.healthCheckItemList.size(), 
            'Should contain Health Check Items for Default, Admin and HH Account models and Admin and HH Account Uniqueness.'
        );
    }

    /**************************************************************************************************************************
    * @description Test to verify getHealthCheckGroup() returns a HealthCheckGroupVModel with a status of
    * failed when a record type id that is not an ID is specified for Default Account Model.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHealthCheckGroupInvalidIdSpecified(){
        AccountModelSettingsService.instance = new STUB_AccountModelSettingsServiceInvalidDefaultAccountId();
        RecordTypeService.instance = new STUB_RecordTypeServiceForGetHealtCheckGroupInvalid();

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVModel = AccountModelHealthCheckVMapper.getInstance().getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHealthCheckAccountModel, 
            hlthChkGroupVModel.label, 
            'Label should be \'' + Label.stgHealthCheckAccountModel + '\''
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed, 
            hlthChkGroupVModel.status, 
            'Status should be \'' + Label.stgHealthCheckStatusFailed + '\''
        );
        System.assertEquals(
            4, 
            hlthChkGroupVModel.healthCheckItemList.size(), 
            'Should contain Health Check Items for Default, Admin and HH Account models and Admin and HH Account Uniqueness.'
        );
    }

    /**************************************************************************************************************************
    * @description Test to verify getHealthCheckGroup() returns a HealthCheckGroupVModel with a status of
    * failed when a record type id that is not an ID is specified for Default Account Model.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHealthCheckGroupNotAnIdSpecified(){
        AccountModelSettingsService.instance = new STUB_AccountModelSettingsServiceNotId();
        RecordTypeService.instance = new STUB_RecordTypeServiceForGetHealtCheckGroupValid();

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVModel = AccountModelHealthCheckVMapper.getInstance().getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHealthCheckAccountModel, 
            hlthChkGroupVModel.label, 
            'Label should be \'' + Label.stgHealthCheckAccountModel + '\''
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed, 
            hlthChkGroupVModel.status, 
            'Status should be \'' + Label.stgHealthCheckStatusFailed + '\''
        );
        System.assertEquals(
            4, 
            hlthChkGroupVModel.healthCheckItemList.size(), 
            'Should contain Health Check Items for Default, Admin and HH Account models and Admin and HH Account Uniqueness.'
        );
    }

    /**************************************************************************************************************************
    * @description Test to verify getHealthCheckGroup() returns a HealthCheckGroupVModel with a status of
    * failed when Admin and HH account record types are the same.
    **************************************************************************************************************************/ 
    @isTest
    private static void getHealthCheckGroupNotUnique(){
        AccountModelSettingsService.instance = new STUB_AccountModelSettingsServiceNotUnique();
        RecordTypeService.instance = new STUB_RecordTypeServiceForGetHealtCheckGroupValid();

        Test.startTest();
        HealthCheckGroupVModel hlthChkGroupVModel = AccountModelHealthCheckVMapper.getInstance().getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHealthCheckAccountModel, 
            hlthChkGroupVModel.label, 
            'Label should be \'' + Label.stgHealthCheckAccountModel + '\''
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed, 
            hlthChkGroupVModel.status, 
            'Status should be \'' + Label.stgHealthCheckStatusFailed + '\''
        );
        System.assertEquals(
            4, 
            hlthChkGroupVModel.healthCheckItemList.size(), 
            'Should contain Health Check Items for Default, Admin and HH Account models and Admin and HH Account Uniqueness.'
        );
    }

    /**************************************************************************************************************************
    * @description Test to verify getAccountRecordTypeUniquenessHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * passed when Admin and HH account record types are not the same.
    **************************************************************************************************************************/ 
    private static void getHouseholdAccountModelHealthCheckItemsUnique(){
        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                '000000000000000002',
                                                                                '000000000000000003');

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getAccountRecordTypeUniquenessHealthCheckItems(accountModelSettingsModel);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusPassed,
                                                                                   1,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = Label.stgHCAccountRecordTypesUnique;
        String expectedFix = Label.stgHealthCheckFixNotApplicable;
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgHCAccountRecordTypeSettingsUnique, 
                                                                                'Pass', 
                                                                                Label.stgHealthCheckStatusPassed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    * @description Test to verify getAccountRecordTypeUniquenessHealthCheckItems() returns a HealthCheckGroupVModel with a status of
    * failed when Admin and HH account record types are the same.
    **************************************************************************************************************************/ 
    private static void getHouseholdAccountModelHealthCheckItemsNotUnique(){
        AccountModelSettingsModel accountModelSettingsModel = new AccountModelSettingsModel('000000000000000001',
                                                                                            '000000000000000005',
                                                                                            '000000000000000005');

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModel = 
            AccountModelHealthCheckVMapper.getInstance().getAccountRecordTypeUniquenessHealthCheckItems(accountModelSettingsModel);
        Test.stopTest();

        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckGroupVModelAssertions(Label.stgHealthCheckAccountModel,
                                                                                   Label.stgHealthCheckStatusFailed,
                                                                                   0,
                                                                                   1,
                                                                                   0,
                                                                                   1,
                                                                                   healthCheckGroupVModel);

        String expectedDescription = Label.stgHCAccountRecordTypesNotUnique;
        String expectedFix = Label.stgHCAccountRecordTypesNotUniqueFix;
        
        AccountModelHealthCheckVMapper_TEST.verifyHealthCheckItemListAssertions(Label.stgHCAccountRecordTypeSettingsUnique, 
                                                                                'Fail', 
                                                                                Label.stgHealthCheckStatusFailed, 
                                                                                expectedDescription, 
                                                                                expectedFix, 
                                                                                healthCheckGroupVModel.healthCheckItemList);
    }

    /**************************************************************************************************************************
    ****************************************************** STUBS **************************************************************
    **************************************************************************************************************************/
    
    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return a valid and active RecordTypeModel from getRecordTypeModelFromMap.
    **************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceValidAndActiveDefaultModel extends RecordTypeService {
        @TestVisible 
        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            return new RecordTypeModel('000000000000000001',
                                       'Test Record Name',
                                       'testRecordDevName',
                                       true);
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return a valid, but inactive RecordTypeModel from getModelByIdMapForSObjectType.
    **************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceForGetHealtCheckGroupValid extends RecordTypeService {
        public override  Map<Id, RecordTypeModel> getModelByIdMapForSObjectType(Schema.SObjectType sObjectType) {

            Map<Id, RecordTypeModel> accRTModelsById = new Map<Id, RecordTypeModel>();

            RecordTypeModel defaultAccRTModel = new RecordTypeModel('000000000000000001',
                                                                    'Test Record Name',
                                                                    'testRecordDevName',
                                                                    true);
                                                                    
            RecordTypeModel adminAccRTModel = new RecordTypeModel('000000000000000002',
                                                                  'Test Admin Record Name',
                                                                  'testAdminRecordDevName',
                                                                  true);
                                                                    
            RecordTypeModel hhAccRTModel = new RecordTypeModel('000000000000000003',
                                                               'Test HH Record Name',
                                                               'testHHRecordDevName',
                                                               true);
                                                                    
            accRTModelsById.put(defaultAccRTModel.id, defaultAccRTModel);
            accRTModelsById.put(adminAccRTModel.id, adminAccRTModel);
            accRTModelsById.put(hhAccRTModel.id, hhAccRTModel);
            
            return accRTModelsById;
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return a valid, but inactive RecordTypeModel from getRecordTypeModelFromMap.
    **************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceValidAndInactiveDefaultModel extends RecordTypeService {
        @TestVisible 
        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            return new RecordTypeModel('000000000000000001',
                                       'Test Record Name',
                                       'testRecordDevName',
                                       false);
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return a valid, but inactive RecordTypeModel from getModelByIdMapForSObjectType.
    **************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceForGetHealtCheckGroupInvalid extends RecordTypeService {
        public override  Map<Id, RecordTypeModel> getModelByIdMapForSObjectType(Schema.SObjectType sObjectType) {
            RecordTypeModel accRTModel = new RecordTypeModel('000000000000000001',
                                                            'Test Record Name',
                                                            'testRecordDevName',
                                                            false);

            return new Map<Id, RecordTypeModel>{accRTModel.id => accRTModel};
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from RecordTypeService to return null.
    **************************************************************************************************************************************/ 
    private class STUB_RecordTypeServiceNullModel extends RecordTypeService {
        @TestVisible 
        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            return null;
        }

        public override  Map<Id, RecordTypeModel> getModelByIdMapForSObjectType(Schema.SObjectType sObjectType) {
            return new Map<Id, RecordTypeModel>();
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from AccountModelSettingsService to return a valid set of account model settings.
    **************************************************************************************************************************************/ 
    private class STUB_AccountModelSettingsServiceValidDefaultAccountId extends AccountModelSettingsService {
        public override AccountModelSettingsModel getAccountModelSettingsModel() {
            return new AccountModelSettingsModel('000000000000000001',
                                                 '000000000000000002',
                                                 '000000000000000003');
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from AccountModelSettingsService to return a set of invalid account model settings.
    **************************************************************************************************************************************/ 
    private class STUB_AccountModelSettingsServiceInvalidDefaultAccountId extends AccountModelSettingsService {
        public override AccountModelSettingsModel getAccountModelSettingsModel() {
            return new AccountModelSettingsModel('000aaaaaaaaaaaaaaa',
                                                 '000aaaaaaaaaaaaaab',
                                                 '000aaaaaaaaaaaaaac');
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from AccountModelSettingsService to return a set of account model settings that are not Ids.
    **************************************************************************************************************************************/ 
    private class STUB_AccountModelSettingsServiceNotId extends AccountModelSettingsService {
        public override AccountModelSettingsModel getAccountModelSettingsModel() {
            return new AccountModelSettingsModel('Not an ID 1',
                                                 'Not an ID 2',
                                                 'Not an ID 3');
        }
    }

    /**************************************************************************************************************************************
    * @description Stub class to simulate the response from AccountModelSettingsService to return a set of account model settings with the
    * same RT set for both Admin and HH accounts.
    **************************************************************************************************************************************/ 
    private class STUB_AccountModelSettingsServiceNotUnique extends AccountModelSettingsService {
        public override AccountModelSettingsModel getAccountModelSettingsModel() {
            return new AccountModelSettingsModel('123000000000000001',
                                                 '123000000000000005',
                                                 '123000000000000005');
        }
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
                                                               HealthCheckGroupVModel healthCheckGroupResult){

        System.assertEquals(expectedLabel, healthCheckGroupResult.label, 'Should have \'' + expectedLabel + '\' label.');
        System.assertEquals(expectedStatus, healthCheckGroupResult.status, 'Should have status of \'' + expectedStatus + '\'.');
        System.assertEquals(expectedPassedCheckCount, healthCheckGroupResult.passedChecks, 'Should have ' + expectedPassedCheckCount + ' passed checks.');
        System.assertEquals(expectedTotalCheckCount, healthCheckGroupResult.totalChecks, 'Should have ' + expectedTotalCheckCount + ' check.');
        System.assertEquals(expectedExpandedRowSize, healthCheckGroupResult.expandedRowsList.size(), 'Should have ' + expectedExpandedRowSize + ' expanded rows.');
        System.assertEquals(expectedHealthCheckItemListSize, healthCheckGroupResult.healthCheckItemList.size(), 'Should have ' + expectedHealthCheckItemListSize + ' health check item.');
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

        for (HealthCheckItemVModel healthCheckItemVModel : healthCheckItemList){
            System.assertEquals(expectedSetting, healthCheckItemVModel.setting, 'Health Check Item setting should be \'' + expectedSetting + '\'.');
            System.assertEquals(expectedStatus, healthCheckItemVModel.status, 'Health Check Item status should be \'' + expectedStatus + '\'.');
            System.assertEquals(expectedStatusLabel, healthCheckItemVModel.statusLabel, 'Health Check Item status label should be \'' + expectedStatusLabel + '\'.');
            System.assertEquals(expectedDescription, healthCheckItemVModel.description, 'Health Check Item description should be correctly set.');
            System.assertEquals(expectedFix, healthCheckItemVModel.recommendedFix, 'Health Check Item recommended fix should be correctly set.');
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
* @group-content ../../ApexDocContent/Tests.htm
* @description Test class for AffiliationMappingsHealthCheckVMapper class.
*/
@isTest 
public with sharing class AffiliationMappingsHCVMapper_TEST {
    /**************************************************************************************************************************
    * @description Test method to verify that the getInstance method returns a new instance of the 
    * AffiliationMappingsHealthCheckVMapper class when one does not already exist.
    ***************************************************************************************************************************/
    @isTest
    private static void getInstanceNew() {

        Test.startTest();
        AffiliationMappingsHealthCheckVMapper AffiliationMappingsHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();
        Test.stopTest();

        System.assertEquals(AffiliationMappingsHealthCheckVMapper.instance, AffiliationMappingsHealthCheckVMapperInstance, 'Instance of mapper class returned should match static instance variable.');
        System.assertEquals(true, AffiliationMappingsHealthCheckVMapperInstance != null, 'Instance of mapper class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test method to verify that the getInstance method returns the existing instance of the 
    * AffiliationMappingsHealthCheckVMapper class when one already exists.
    ***************************************************************************************************************************/
    @isTest
    private static void getInstanceExisting() {

        Test.startTest();
        AffiliationMappingsHealthCheckVMapper AffiliationMappingsHealthCheckVMapperInstance1 = 
            AffiliationMappingsHealthCheckVMapper.getInstance();
        AffiliationMappingsHealthCheckVMapper AffiliationMappingsHealthCheckVMapperInstance2 = 
            AffiliationMappingsHealthCheckVMapper.getInstance();
        Test.stopTest();

        System.assertEquals(AffiliationMappingsHealthCheckVMapper.instance, AffiliationMappingsHealthCheckVMapperInstance1, 'Instance of mapper class returned should match static instance variable.');
        System.assertEquals(AffiliationMappingsHealthCheckVMapperInstance1, AffiliationMappingsHealthCheckVMapperInstance2, 'Subsequent retrievals of mapper class instance should return existing instance.');
        System.assertEquals(true, AffiliationMappingsHealthCheckVMapperInstance1 != null, 'Instance of mapper class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locateRecordTypeService() returns an instance of the RecordTypeService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locateRecordTypeServiceValid() {
        Test.startTest();
        RecordTypeService recordTypeServiceInstance = AccountModelHealthCheckVMapper.getInstance().locateRecordTypeService();
        Test.stopTest();

        System.assertEquals(RecordTypeService.getInstance(), recordTypeServiceInstance, 'Should return instance of RecordTypeService class.');
        System.assertEquals(true, recordTypeServiceInstance != null, 'Instance of RecordTypeService class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locateAffiliationMappingsService() returns an instance of the AffiliationMappingsService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locateAffiliationMappingsServiceValid() {
        Test.startTest();
        AffiliationMappingsService AffiliationMappingsServiceInstance = AffiliationMappingsHealthCheckVMapper.getInstance().locateAffiliationMappingsService();
        Test.stopTest();

        System.assertEquals(AffiliationMappingsService.getInstance(), AffiliationMappingsServiceInstance, 'Should return instance of AffiliationMappingsService class.');
        System.assertEquals(true, AffiliationMappingsServiceInstance != null, 'Instance of AffiliationMappingsService class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locateLookupFieldService() returns an instance of the LookupFieldService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locateLookupFieldServiceValid() {
        Test.startTest();
        LookupFieldService LookupFieldServiceInstance = AffiliationMappingsHealthCheckVMapper.getInstance().locateLookupFieldService();
        Test.stopTest();

        System.assertEquals(LookupFieldService.getInstance(), LookupFieldServiceInstance, 'Should return instance of LookupFieldService class.');
        System.assertEquals(true, LookupFieldServiceInstance != null, 'Instance of LookupFieldService class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locatePicklistEntryService() returns an instance of the PicklistEntryService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locatePicklistEntryServiceValid() {
        Test.startTest();
        PicklistEntryService PicklistEntryServiceInstance = AffiliationMappingsHealthCheckVMapper.getInstance().locatePicklistEntryService();
        Test.stopTest();

        System.assertEquals(PicklistEntryService.getInstance(), PicklistEntryServiceInstance, 'Should return instance of PicklistEntryService class.');
        System.assertEquals(true, PicklistEntryServiceInstance != null, 'Instance of PicklistEntryService class should not be null.');
    }

    /**************************************************************************************************************************
    * @description Test to verify locateStringHandlingService() returns an instance of the StringHandlingService class.
    **************************************************************************************************************************/ 
    @isTest
    private static void locateStringHandlingServiceValid() {
        Test.startTest();
        StringHandlingService StringHandlingServiceInstance = AffiliationMappingsHealthCheckVMapper.getInstance().locateStringHandlingService();
        Test.stopTest();

        System.assertEquals(StringHandlingService.getInstance(), StringHandlingServiceInstance, 'Should return instance of StringHandlingService class.');
        System.assertEquals(true, StringHandlingServiceInstance != null, 'Instance of StringHandlingService class should not be null.');
    }

    /***************************************************************************
    * @description Test method to verify that getHealthCheckGroup handles all
    * passed health checks
    ***************************************************************************/
    @isTest
    private static void getHealthCheckGroupAllPassed() {
        AffiliationMappingsService.instance = new STUB_AffiliationMappingsService();
        RecordTypeService.instance = new STUB_RecordTypeService();
        LookupFieldService.instance = new STUB_LookupFieldService();
        PicklistEntryService.instance = new STUB_PicklistEntryServiceRole();

        STUB_AffiliationMappingsHealthCheckVMapperPass AffiliationMappingsHealthCheckVMapperStub =
            new STUB_AffiliationMappingsHealthCheckVMapperPass();
        AffiliationMappingsHealthCheckVMapper.instance = AffiliationMappingsHealthCheckVMapperStub;  

        AffiliationMappingsHealthCheckVMapper AffiliationMappingsHealthCheckVMapper =
            AffiliationMappingsHealthCheckVMapper.getInstance();

        Integer numberOfHealthChecks = 6; //NOTE: Update when adding new Health Check

        Test.startTest();
            HealthCheckGroupVModel healthCheckGroupVModel =
                AffiliationMappingsHealthCheckVMapperStub.getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHealthCheckAffiliationMappings,
            healthCheckGroupVModel.label,
            'Label of returned health check should match expected custom label.'
        );
        System.assertEquals(
            Label.stgHealthCheckStatusPassed,
            healthCheckGroupVModel.status,
            'Status of returned health check should match expected custom label.'
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModel.passedChecks,
            'Number of passed checks of returned health check should match expected custom label.'
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModel.totalChecks,
            'Number of total checks of returned health check should match expected custom label.'
        );
        System.assertEquals(
            0,
            healthCheckGroupVModel.expandedRowsList.size(),
            'No health checks should fail, making expanded rows list size 0.'
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModel.healthCheckItemList[0].healthCheckItemList.size(),
            'Number of health check items of returned health check should match total number of health checks.'
        );
    }

    /***************************************************************************
    * @description Test method to verify that getHealthCheckGroup handles all
    * failed health checks
    ***************************************************************************/
    @isTest
    private static void getHealthCheckGroupAllFail() {
        AffiliationMappingsService.instance = new STUB_AffiliationMappingsServiceUnfound();
        RecordTypeService.instance = new STUB_RecordTypeServiceNull();

        STUB_AffiliationMappingsHealthCheckVMapperFail AffiliationMappingsHealthCheckVMapperStub =
            new STUB_AffiliationMappingsHealthCheckVMapperFail();

        AffiliationMappingsHealthCheckVMapper.instance = AffiliationMappingsHealthCheckVMapperStub;  

        AffiliationMappingsHealthCheckVMapper AffiliationMappingsHealthCheckVMapper =
            AffiliationMappingsHealthCheckVMapper.getInstance();

        Integer numberOfHealthChecks = 6; //NOTE: Update when adding new health checks

        Test.startTest();
            HealthCheckGroupVModel healthCheckGroupVModel =
                AffiliationMappingsHealthCheckVMapper.getHealthCheckGroup();
        Test.stopTest();

        System.assertEquals(
            Label.stgHealthCheckAffiliationMappings,
            healthCheckGroupVModel.label,
            'Label of returned health check should match expected custom label.'
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed,
            healthCheckGroupVModel.status,
            'Status of returned health check should match expected custom label.'
        );
        System.assertEquals(
            0,
            healthCheckGroupVModel.passedChecks,
            'Number of passed checks should be 0.'
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModel.totalChecks,
            'Number of total checks of returned health check should match expected custom label.'
        );
        System.assertEquals(
            1,
            healthCheckGroupVModel.expandedRowsList.size(),
            'All health checks should fail, making expanded rows list size 1.'
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModel.healthCheckItemList[0].healthCheckItemList.size(),
            'Number of health check items of returned health check should match total number of health checks.'
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getValidRecordTypeHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Passed status when an affiliation mapping is mapped to
    * an Account record type that is valid and active.
    *****************************************************************************************/
    @isTest 
    private static void getValidRecordTypeHealthCheckGroupVModelValid() {
        RecordTypeService.instance = new STUB_RecordTypeService();
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Active RecordType Label',
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getValidRecordTypeHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new RecordTypeModel(
                    '000000000000000006',
                    'Active RecordType Label',
                    'activeRTDevName',
                    true
                )
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            1,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAccRecordTypeTitle,
            'Pass',
            Label.stgHealthCheckStatusPassed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCRecordTypeValid, 
                new List<Object> {'Active RecordType Label', 'activeRTDevName'}
            ),
            Label.stgHealthCheckFixNotApplicable,
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getValidRecordTypeHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when an affiliation mapping is mapped to
    * an Account record type that is valid, but inactive.
    *****************************************************************************************/
    @isTest 
    private static void getValidRecordTypeHealthCheckGroupVModelInactiveRT() {
        RecordTypeService.instance = new STUB_RecordTypeServiceInactive();
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'inactiveRTDevName',
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getValidRecordTypeHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new RecordTypeModel(
                    '000000000000000005',
                    'Inactive RecordType Label',
                    'inactiveRTDevName',
                    false
                )
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAccRecordTypeTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCRecordTypeInactive, 
                new List<Object> {'Inactive RecordType Label', 'inactiveRTDevName'}
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAccRecordTypeInactiveFix, 
                new List<Object> {'Inactive RecordType Label', 'inactiveRTDevName'}
            ),
            0
        );  
    }

    /*****************************************************************************************
    * @description Test method to verify getValidRecordTypeHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when an affiliation mapping contains a
    * value that does not match a record type by name or label.
    *****************************************************************************************/
    @isTest 
    private static void getValidRecordTypeHealthCheckGroupVModelNonExistentRT() {
        RecordTypeService.instance = new STUB_RecordTypeServiceNull();
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingModelsList = new List<AffiliationMappingsModel>{
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Non Existent Record Type Name', 
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getValidRecordTypeHealthCheckGroupVModel(
                affiliationMappingModelsList[0],
                null
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAccRecordTypeTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCRecordTypeNotFound, 
                new List<Object>{affiliationMappingModelsList[0].accountRecordTypeFieldValue} 
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAccRecordTypeNotFoundFix, 
                new List<Object>{affiliationMappingModelsList[0].accountRecordTypeFieldValue}
            ),
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getAccountRecordTypeUniquenessHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Passed status when a valid and active account record type is unique
    * in Affiliation Mappings
    *****************************************************************************************/
    @isTest 
    private static void getAccountRecordTypeUniquenessHealthCheckGroupVModelValid() {
        RecordTypeService.instance = new STUB_RecordTypeService();
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Active RecordType Label',
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping2',
                'Active RecordType Label2',
                'Test Primary Field2',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getAccountRecordTypeUniquenessHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new RecordTypeModel(
                    '000000000000000006',
                    'Active RecordType Label',
                    'activeRTDevName',
                    true
                ),
                new Set<Id>()
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            1,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAccRecordTypeUniqueTitle,
            'Pass',
            Label.stgHealthCheckStatusPassed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAccRecordTypeUnique, 
                new List<Object> {'Active RecordType Label', 'activeRTDevName'}
            ),
            Label.stgHealthCheckFixNotApplicable,
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getAccountRecordTypeUniquenessHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when the account record type does not exist
    *****************************************************************************************/
    @isTest 
    private static void getAccountRecordTypeUniquenessHealthCheckGroupVModelRTNonExistent() {
        RecordTypeService.instance = new STUB_RecordTypeServiceNull();
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel>{
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Non Existent Record Type Name', 
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping2',
                'Active RecordType Label2',
                'Test Primary Field2',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getAccountRecordTypeUniquenessHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                null,
                new Set<Id>()
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAccRecordTypeUniqueTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCRecordTypeNotFound, 
                new List<Object>{affiliationMappingsModelsList[0].accountRecordTypeFieldValue} 
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAccRecordTypeNotFoundFix, 
                new List<Object>{affiliationMappingsModelsList[0].accountRecordTypeFieldValue}
            ),
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getAccountRecordTypeUniquenessHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when the account record type is inactive
    *****************************************************************************************/
    @isTest 
    private static void getAccountRecordTypeUniquenessHealthCheckGroupVModelRTInactive() {
        RecordTypeService.instance = new STUB_RecordTypeServiceInactive();
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'inactiveRTDevName',
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping2',
                'Active RecordType Label2',
                'Test Primary Field2',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getAccountRecordTypeUniquenessHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new RecordTypeModel(
                    '000000000000000005',
                    'Inactive RecordType Label',
                    'inactiveRTDevName',
                    false
                ),
                new Set<Id>()
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAccRecordTypeUniqueTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCRecordTypeInactive, 
                new List<Object> {'Inactive RecordType Label', 'inactiveRTDevName'}
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAccRecordTypeInactiveFix, 
                new List<Object> {'Inactive RecordType Label', 'inactiveRTDevName'}
            ),
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getAccountRecordTypeUniquenessHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when a valid and active account record type is not unique
    * in Affiliation Mappings
    *****************************************************************************************/
    @isTest 
    private static void getAccountRecordTypeUniquenessHealthCheckGroupVModelValidDuplicate() {
        RecordTypeService.instance = new STUB_RecordTypeService();
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Active RecordType Label',
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping2',
                'Active RecordType Label',
                'Test Primary Field2',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getAccountRecordTypeUniquenessHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new RecordTypeModel(
                    '000000000000000006',
                    'Active RecordType Label',
                    'activeRTDevName',
                    true
                ),
                new Set<Id>{'000000000000000006'}
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAccRecordTypeUniqueTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAccRecordTypeNotUnique, 
                new List<Object> {'Active RecordType Label', 'activeRTDevName'}
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAccRecordTypeUniqueFix, 
                new List<Object> {'Active RecordType Label', 'activeRTDevName'}
            ),
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getValidContactPrimaryFieldHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Passed status when an Primary Affilition field specified
    * in affiliation mappings matches the developer name of a field that corresponds to a  
    * lookup to Account on Contact. 
    *****************************************************************************************/
    @isTest 
    private static void getValidContactPrimaryFieldHealthCheckGroupVModelValidByName() {
        LookupFieldService.instance = new STUB_LookupFieldServiceDevNameMatch();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                'Valid Contact Lookup Field Name',
                true,
                'Test Status',
                'Test Role'
            )
        };

        LookupFieldModel expectedLookupFieldModel = 
            new LookupFieldModel(
                'Valid Contact Lookup Field Name',
                'Valid Contact Lookup Field Label'
            );

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getValidContactPrimaryFieldHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                expectedLookupFieldModel
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            1,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapContactPrimaryFieldTitle,  
            'Pass',
            Label.stgHealthCheckStatusPassed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldValid, 
                new List<Object> {
                    affiliationMappingsModelsList[0].primaryAffiliationField, 
                    expectedLookupFieldModel.name
                }
            ),
            Label.stgHealthCheckFixNotApplicable,
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getValidContactPrimaryFieldHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Passed status when an Primary Affilition field specified
    * in affiliation mappings matches the label name of a field that corresponds to a  
    * lookup to Account on Contact. 
    *****************************************************************************************/
    @isTest 
    private static void getValidContactPrimaryFieldHealthCheckGroupVModelValidByLabel() {
        LookupFieldService.instance = new STUB_LookupFieldServiceLabelMatch();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                'Valid Contact Lookup Field Name',
                true,
                'Test Status',
                'Test Role'
            )
        };

        LookupFieldModel expectedLookupFieldModel = 
            new LookupFieldModel(
                'Valid Contact Lookup Field Name',
                'Valid Contact Lookup Field Label'
            );

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getValidContactPrimaryFieldHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                expectedLookupFieldModel
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            1,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapContactPrimaryFieldTitle,  
            'Pass',
            Label.stgHealthCheckStatusPassed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldValid, 
                new List<Object> {
                    affiliationMappingsModelsList[0].primaryAffiliationField, 
                    expectedLookupFieldModel.name}
            ),
            Label.stgHealthCheckFixNotApplicable,
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getValidContactPrimaryFieldHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when mapping specifies a 
    * Primary Affl Field that does not match a field on Contact (by dev name or label name).
    *****************************************************************************************/
    @isTest 
    private static void getValidContactPrimaryFieldHealthCheckGroupVModelNoContactFieldMatch() {
        LookupFieldService.instance = new STUB_LookupFieldServiceNull();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getValidContactPrimaryFieldHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                null
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapContactPrimaryFieldTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldInvalid, 
                new List<Object> {affiliationMappingsModelsList[0].primaryAffiliationField}
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContPrimaryFieldInvalidFix, 
                new List<Object> {affiliationMappingsModelsList[0].primaryAffiliationField}
            ),
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getHealthCheckItemVModelForAffiliationMappingsModel 
    * returns a HealthCheckItemVModel with the key set to affiliationMappingsModel.name when
    * there is no Account record type matching the RT specified in the affiliation mapping.
    *****************************************************************************************/
    @isTest
    private static void getHealthCheckItemVModelForAffiliationMappingsModelValidRT() {
        AffiliationMappingsModel affiliationMappingsModel = new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                '000000000000000007',
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            );

            RecordTypeModel recordTypeModel = new RecordTypeModel(
                '000000000000000007',
                'Active RecordType Name',
                'ActiveRTDevName',
                true
            );

        AffiliationMappingsHealthCheckVMapper affiliationMappingsHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        Test.startTest();
        HealthCheckItemVModel healthCheckItemVModel = 
            affiliationMappingsHealthCheckVMapperInstance.getHealthCheckItemVModelForAffiliationMappingsModel( 
                affiliationMappingsModel, 
                recordTypeModel
            );
        Test.stopTest();

        List<String> listForSettingsLabel =
            new List<String>{affiliationMappingsModel.accountRecordTypeFieldValue};
        
        String healthCheckItemSetting = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAffiliationMappingSettingHeading,
            listForSettingsLabel
        );
        
        System.assertEquals(affiliationMappingsModel.name, healthCheckItemVModel.key, 'Health check item key should be \'' + affiliationMappingsModel.name + '\'.');
        System.assertEquals(healthCheckItemSetting, healthCheckItemVModel.setting, 'Health check item key should be \'' + healthCheckItemSetting + '\'.');
        System.assertEquals('Pass', healthCheckItemVModel.status, 'Health check item key should be \'Pass\'.');
        System.assertEquals(Label.stgHealthCheckStatusPassed, healthCheckItemVModel.statusLabel, 'Health check item key should be \'' + Label.stgHealthCheckStatusPassed + '\'.');
        System.assertEquals('', healthCheckItemVModel.description, 'Health check item description should be blank.');
        System.assertEquals('', healthCheckItemVModel.recommendedFix, 'Health check item recommended fix should be blank.');
        System.assertEquals(0, healthCheckItemVModel.healthCheckItemList.size(), 'Health check item should not have any child health check items.');
    }
 
    /*****************************************************************************************
    * @description Test method to verify getValidContactPrimaryFieldHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when mapping specifies a 
    * Primary Affl Field is empty.
    *****************************************************************************************/
    @isTest 
    private static void getValidContactPrimaryFieldHealthCheckGroupVModelNullField() {
        LookupFieldService.instance = new STUB_LookupFieldServiceNull();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getValidContactPrimaryFieldHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                null
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapContactPrimaryFieldTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldInvalid, 
                new List<Object> {affiliationMappingsModelsList[0].primaryAffiliationField}
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContPrimaryFieldInvalidFix, 
                new List<Object> {affiliationMappingsModelsList[0].primaryAffiliationField}
            ),
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getHealthCheckItemVModelForAffiliationMappingsModel 
    * returns a HealthCheckItemVModel with the key set to affiliationMappingsModel.name when
    * there is no Account record type matching the RT specified in the affiliation mapping.
    *****************************************************************************************/
    @isTest
    private static void getHealthCheckItemVModelForAffiliationMappingsModelNullRT() {
        AffiliationMappingsModel affiliationMappingsModel = new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                '000000000000000007',
                'Test Primary Field',
                true,
                'Test Status',
                'Test Role'
            );

        AffiliationMappingsHealthCheckVMapper affiliationMappingsHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        Test.startTest();
        HealthCheckItemVModel healthCheckItemVModel = 
            affiliationMappingsHealthCheckVMapperInstance.getHealthCheckItemVModelForAffiliationMappingsModel( 
                affiliationMappingsModel, 
                null
            );
        Test.stopTest();

        List<String> listForSettingsLabel =
            new List<String>{affiliationMappingsModel.accountRecordTypeFieldValue};
        
        String healthCheckItemSetting = StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
            Label.stgHCAffiliationMappingSettingHeading,
            listForSettingsLabel
        );
        
        System.assertEquals(affiliationMappingsModel.name, healthCheckItemVModel.key);
        System.assertEquals(healthCheckItemSetting, healthCheckItemVModel.setting);
        System.assertEquals('Pass', healthCheckItemVModel.status);
        System.assertEquals(Label.stgHealthCheckStatusPassed, healthCheckItemVModel.statusLabel);
        System.assertEquals('', healthCheckItemVModel.description);
        System.assertEquals('', healthCheckItemVModel.recommendedFix);
        System.assertEquals(0, healthCheckItemVModel.healthCheckItemList.size());
    }

    /*****************************************************************************************
    * @description Test method to verify getContactPrimaryFieldUniquenessHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Passed status when a unique Primary Affilition field specified
    * in affiliation mappings matches the developer name of a field that corresponds to a  
    * lookup to Account on Contact. 
    *****************************************************************************************/
    @isTest 
    private static void getContactPrimaryFieldUniquenessHealthCheckGroupVModelValid() {
        LookupFieldService.instance = new STUB_LookupFieldServiceDevNameMatch();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                'Valid Contact Lookup Field Name',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getContactPrimaryFieldUniquenessHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new LookupFieldModel(
                    'Valid Contact Lookup Field Name',
                    'Valid Contact Lookup Field Label'
                ),
                new Set<String>()
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            1,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapContPrimaryFieldUniqueTitle,  
            'Pass',
            Label.stgHealthCheckStatusPassed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldUnique, 
                new List<Object> {
                    'Valid Contact Lookup Field Label', 
                    'Valid Contact Lookup Field Name'}
            ),
            Label.stgHealthCheckFixNotApplicable,
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getContactPrimaryFieldUniquenessHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when the primary contact field is not valid
    *****************************************************************************************/
    @isTest 
    private static void getContactPrimaryFieldUniquenessHealthCheckGroupVModelFieldNotExist() {
        LookupFieldService.instance = new STUB_LookupFieldServiceDevNameMatch();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                'Valid Contact Lookup Field Name',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getContactPrimaryFieldUniquenessHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                null,
                new Set<String>()
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapContPrimaryFieldUniqueTitle,  
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldInvalid, 
                new List<Object> {'Valid Contact Lookup Field Name'}
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContPrimaryFieldInvalidFix, 
                new List<Object> {'Valid Contact Lookup Field Name'}
            ),
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getContactPrimaryFieldUniquenessHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when an account record type matched to multiple
    * Primary Affilition fields specified in affiliation mappings matches the developer name
    * of a field that corresponds to a lookup to Account on Contact. 
    *****************************************************************************************/
    @isTest 
    private static void getContactPrimaryFieldUniquenessHealthCheckGroupVModelFieldDuplicate() {
        LookupFieldService.instance = new STUB_LookupFieldServiceDevNameMatch();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                'Valid Contact Lookup Field Name',
                true,
                'Test Status',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getContactPrimaryFieldUniquenessHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new LookupFieldModel(
                    'Valid Contact Lookup Field Name',
                    'Valid Contact Lookup Field Label'
                ),
                new Set<String>{'Valid Contact Lookup Field Name'}
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapContPrimaryFieldUniqueTitle,  
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldNotUnique, 
                new List<Object> {
                    'Valid Contact Lookup Field Label', 
                    'Valid Contact Lookup Field Name'}
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapContactPrimaryFieldUniqueFix, 
                new List<Object> {
                    'Valid Contact Lookup Field Label', 
                    'Valid Contact Lookup Field Name'}
            ),
            0
        );
    }

    /***************************************************************************
    * @description Test method to verify that
    * getAffiliationMappingsHealthCheckResults returns the expected passing health
    * check
    ***************************************************************************/
    @isTest
    private static void getAffiliationMappingsHealthCheckResultsPass() {
        STUB_AffiliationMappingsService affiliationMappingsServiceStub = 
            new STUB_AffiliationMappingsService();

        STUB_RecordTypeService recordTypeServiceStub = 
            new STUB_RecordTypeService();

        AffiliationMappingsHealthCheckVMapper.instance = 
            new STUB_AffiliationMappingsHealthCheckVMapperSub();
        
        AffiliationMappingsHealthCheckVMapper AffiliationMappingsHealthCheckVMapperInstance =
            AffiliationMappingsHealthCheckVMapper.getInstance();
        
        AffiliationMappingsModel affiliationMappingsModel =
            affiliationMappingsServiceStub.getAffiliationMappingsModels()[0];

        Integer numberOfHealthChecks = 6; // NOTE: Increment when adding health checks

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            affiliationMappingsHealthCheckVMapperInstance.getAffiliationMappingsHealthCheckResults(
                affiliationMappingsModel,
                new RecordTypeModel(
                    '000000000000001234', 
                    'Test Account Record Type',
                    'Test_Account_Record_Type', 
                    true
                ),
                new LookupFieldModel(
                    'Test_Lookup_Field', 
                    'Test Lookup Field'
                ),
                new Map<String, PicklistEntryModel>(),
                new Map<String, PicklistEntryModel>(),
                new Set<Id>(),
                new Set<String>()
            );
        Test.stopTest();

        System.assertEquals(
            '',
            healthCheckGroupVModelResult.label,
            'Label should equal expected value of blank'
        );
        System.assertEquals(
            Label.stgHealthCheckStatusPassed,
            healthCheckGroupVModelResult.status,
            'Status should default to passed'
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModelResult.passedChecks,
            'Passed checks should equal expected value of ' + numberOfHealthChecks
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModelResult.totalChecks,
            'Total checks should equal expected value of ' + numberOfHealthChecks
        );
        System.assertEquals(
            0,
            healthCheckGroupVModelResult.expandedRowsList.size(),
            'Expanded rows list should have a size of 0'
        );
        System.assertEquals(
            1,
            healthCheckGroupVModelResult.healthCheckItemList.size(),
            'Health Check Item list should have a size of 1'
        );
    }

    /***************************************************************************
    * @description Test method to verify that
    * getAffiliationMappingsHealthCheckResults returns the expected failed health
    * check
    ***************************************************************************/
    @isTest
    private static void getAffiliationMappingsHealthCheckResultsFail() {
        List<Affl_Mappings__c> affiliationMappingsList = new List<Affl_Mappings__c>();
        affiliationMappingsList.add(
            new Affl_Mappings__c(
                Name = 'Test Account', 
                Account_Record_Type__c = 'Test Record Type', 
                Primary_Affl_Field__c = UTIL_Namespace.StrTokenNSPrefix('Test_Organization__c')
            )
        );
        insert affiliationMappingsList;

        STUB_AffiliationMappingsService affiliationMappingsServiceStub = 
            new STUB_AffiliationMappingsService();

        STUB_RecordTypeService recordTypeServiceStub = 
            new STUB_RecordTypeService();

        AffiliationMappingsHealthCheckVMapper.instance = 
            new STUB_AffiliationMappingsHealthCheckVMapperSubFail();
        
        AffiliationMappingsHealthCheckVMapper affiliationMappingsHealthCheckVMapperInstance =
            AffiliationMappingsHealthCheckVMapper.getInstance();
        
        AffiliationMappingsModel affiliationMappingsModel = 
            affiliationMappingsHealthCheckVMapperInstance.locateAffiliationMappingsService().getAffiliationMappingsModels()[0];
        
        Integer numberOfHealthChecks = 6; // NOTE: Increment when adding health checks

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            affiliationMappingsHealthCheckVMapperInstance.getAffiliationMappingsHealthCheckResults(
                affiliationMappingsModel,
                new RecordTypeModel(
                    '000000000000001234', 
                    'Test Account Record Type',
                    'Test_Account_Record_Type', 
                    true
                ),
                new LookupFieldModel(
                    'Test_Lookup_Field', 
                    'Test Lookup Field'
                ),
                new Map<String, PicklistEntryModel>(),
                new Map<String, PicklistEntryModel>(),
                new Set<Id>(),
                new Set<String>()
            );
        Test.stopTest();

        System.assertEquals(
            '',
            healthCheckGroupVModelResult.label,
            'Label should equal expected value of blank'
        );
        System.assertEquals(
            Label.stgHealthCheckStatusFailed,
            healthCheckGroupVModelResult.status,
            'Status should equal failed'
        );
        System.assertEquals(
            0,
            healthCheckGroupVModelResult.passedChecks,
            'Passed checks should equal expected value of 0.'
        );
        System.assertEquals(
            numberOfHealthChecks,
            healthCheckGroupVModelResult.totalChecks,
            'Total checks should equal expected value of ' + numberOfHealthChecks
        );
        System.assertEquals(
            1,
            healthCheckGroupVModelResult.expandedRowsList.size(),
            'Expanded rows list should have a size of 1.'
        );
        System.assertEquals(
            1,
            healthCheckGroupVModelResult.healthCheckItemList.size(),
            'Health Check Item list should have a size of 1'
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingRoleHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Passed status when the Auto Enrollment Role is populated and
    * corresponds to a value in the Role picklist field on Affiliation__c that is active.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingRoleHealthCheckGroupVModelValidAndActivePicklistField() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceValid();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Test Status',
                'Test Auto Enrollment'
            )
        };

        Map<String, PicklistEntryModel> affiliationRolePicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                true
            ),

            'Auto Enrollment Role Name 2' => new PicklistEntryModel(
                'Auto Enrollment Role Name 2',
                'Auto Enrollment Role Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingRoleHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationRolePicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            1,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollRoleTitle,
            'Pass',
            Label.stgHealthCheckStatusPassed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollRoleValid, 
                new List<Object> {
                    affiliationRolePicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentRole).label, 
                    affiliationRolePicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentRole).name
                }
            ),
            Label.stgHealthCheckFixNotApplicable,
            0
        ); 
    }
    
    /*****************************************************************************************
    * @description Test method to verify getActiveExistingRoleHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when the Auto Enrollment Role is populated and
    * corresponds to a value in the Role picklist field on Affiliation__c that is inactive.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingRoleHealthCheckGroupVModelValidAndInActivePicklistField() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceInactive();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Test Status',
                'Test Auto Enrollment'
            )
        };

        Map<String, PicklistEntryModel> affiliationRolePicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                false
            ),

            'Auto Enrollment Role Name 2' => new PicklistEntryModel(
                'Auto Enrollment Role Name 2',
                'Auto Enrollment Role Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingRoleHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationRolePicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollRoleTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollRoleInactive, 
                new List<Object> {
                    affiliationMappingsModelsList[0].autoProgramEnrollmentRole, 
                    affiliationRolePicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentRole).name
                }
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollRoleInactiveFix, 
                new List<Object> {
                    affiliationMappingsModelsList[0].autoProgramEnrollmentRole, 
                    affiliationRolePicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentRole).name
                }
            ),
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingRoleHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when the Auto Enrollment Role is populated and
    * does not correspond to a value in the Role picklist field on Affiliation__c.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingRoleHealthCheckGroupVModelInvalidPicklistField() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceNull();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Test Status',
                'Invalid Auto Enrollment Role'
            )
        };

        Map<String, PicklistEntryModel> affiliationRolePicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                true
            ),

            'Auto Enrollment Role Name 2' => new PicklistEntryModel(
                'Auto Enrollment Role Name 2',
                'Auto Enrollment Role Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingRoleHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationRolePicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollRoleTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollRoleNotFound, 
                new List<Object> {affiliationMappingsModelsList[0].autoProgramEnrollmentRole}
            ),
            Label.stgHCAfflMapAutoEnrollRoleNotFoundFix,
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingRoleHealthCheckGroupVModel returns an
    * empty HealthCheckGroupVModel with a Failed status when the Auto Enrollment Role is not 
    * populated for an affiliation mapping.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingRoleHealthCheckGroupVModelBlankRole() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceNull();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Test Status',
                ''
            )
        };

        Map<String, PicklistEntryModel> affiliationRolePicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                true
            ),

            'Auto Enrollment Role Name 2' => new PicklistEntryModel(
                'Auto Enrollment Role Name 2',
                'Auto Enrollment Role Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingRoleHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationRolePicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollRoleTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollRoleNotFound, 
                new List<Object> {affiliationMappingsModelsList[0].autoProgramEnrollmentRole}
            ),
            Label.stgHCAfflMapAutoEnrollRoleNotFoundFix,
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingRoleHealthCheckGroupVModel returns an
    * empty HealthCheckGroupVModel with a Passed status when the Auto Enrollment feature is not
    * enabled.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingRoleHealthCheckGroupVModelAutoEnrollDisabled() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                false,
                '',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingRoleHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new Map<String, PicklistEntryModel>()
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            0,
            0,
            0,
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingStatusHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Passed status when the Auto Enrollment Status is populated and
    * corresponds to a value in the Status picklist field on Affiliation__c that is active.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingStatusHealthCheckGroupVModelValidAndActivePicklistField() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceValid();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Test Auto Enrollment',
                'Test Role'
            )
        };

        Map<String, PicklistEntryModel> affiliationStatusPicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                true
            ),

            'Auto Enrollment Status Name 2' => new PicklistEntryModel(
                'Auto Enrollment Status Name 2',
                'Auto Enrollment Status Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingStatusHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationStatusPicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            1,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollStatusTitle,
            'Pass',
            Label.stgHealthCheckStatusPassed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollStatusValid, 
                new List<Object> {
                affiliationStatusPicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentStatus).label, 
                affiliationStatusPicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentStatus).name
                }
            ),
            Label.stgHealthCheckFixNotApplicable,
            0
        ); 
    }
    
    /*****************************************************************************************
    * @description Test method to verify getActiveExistingStatusHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when the Auto Enrollment Status is populated and
    * corresponds to a value in the Status picklist field on Affiliation__c that is inactive.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingStatusHealthCheckGroupVModelValidAndInActivePicklistField() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceInactive();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Test Auto Enrollment',
                'Test Role'
            )
        };

        Map<String, PicklistEntryModel> affiliationStatusPicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                false
            ),

            'Auto Enrollment Status Name 2' => new PicklistEntryModel(
                'Auto Enrollment Status Name 2',
                'Auto Enrollment Status Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingStatusHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationStatusPicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollStatusTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollStatusInactive, 
                new List<Object> {
                    affiliationMappingsModelsList[0].autoProgramEnrollmentStatus, 
                    affiliationStatusPicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentStatus).name
                }
            ),
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollStatusInactiveFix, 
                new List<Object> {
                    affiliationMappingsModelsList[0].autoProgramEnrollmentStatus, 
                    affiliationStatusPicklistEntryModelByName.get(affiliationMappingsModelsList[0].autoProgramEnrollmentStatus).name
                }
            ),
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingStatusHealthCheckGroupVModel returns a 
    * HealthCheckGroupVModel with a Failed status when the Auto Enrollment Status is populated and
    * does not correspond to a value in the Status picklist field on Affiliation__c.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingStatusHealthCheckGroupVModelInvalidPicklistField() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceNull();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                'Invalid Auto Enrollment Status',
                'Test Enrollment Role'
            )
        };

        Map<String, PicklistEntryModel> affiliationStatusPicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                true
            ),

            'Auto Enrollment Status Name 2' => new PicklistEntryModel(
                'Auto Enrollment Status Name 2',
                'Auto Enrollment Status Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingStatusHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationStatusPicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollStatusTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollStatusNotFound, 
                new List<Object> {affiliationMappingsModelsList[0].autoProgramEnrollmentStatus}
            ),
            Label.stgHCAfflMapAutoEnrollStatusNotFoundFix,
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingStatusHealthCheckGroupVModel returns an
    * empty HealthCheckGroupVModel with a Failed status when the Auto Enrollment Status is not 
    * populated for an affiliation mapping.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingStatusHealthCheckGroupVModelBlankStatus() {
        PicklistEntryService.instance = new STUB_PicklistEntryServiceNull();

        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                true,
                '',
                'Test Role'
            )
        };

        Map<String, PicklistEntryModel> affiliationStatusPicklistEntryModelByName = new Map<String, PicklistEntryModel> {
            'Test Auto Enrollment' => new PicklistEntryModel(
                'Test Auto Enrollment',
                'Auto Enrollment Label',
                true
            ),

            'Auto Enrollment Status Name 2' => new PicklistEntryModel(
                'Auto Enrollment Status Name 2',
                'Auto Enrollment Status Label 2',
                true
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingStatusHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                affiliationStatusPicklistEntryModelByName
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusFailed,
            0,
            1,
            0,
            1
        );

        AffiliationMappingsHCVMapper_TEST.validateHCItemAssertions(
            healthCheckGroupVModelResult,
            Label.stgHCAfflMapAutoEnrollStatusTitle,
            'Fail',
            Label.stgHealthCheckStatusFailed,
            StringHandlingService.getInstance().formatStringWithApostrophesAndParameters(
                Label.stgHCAfflMapAutoEnrollStatusNotFound, 
                new List<Object> {affiliationMappingsModelsList[0].autoProgramEnrollmentStatus}
            ),
            Label.stgHCAfflMapAutoEnrollStatusNotFoundFix,
            0
        ); 
    }

    /*****************************************************************************************
    * @description Test method to verify getActiveExistingStatusHealthCheckGroupVModel returns an
    * empty HealthCheckGroupVModel with a Passed status when the Auto Enrollment feature is not
    * enabled.
    *****************************************************************************************/
    @isTest 
    private static void getActiveExistingStatusHealthCheckGroupVModelAutoEnrollDisabled() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Record Type Name', 
                '',
                false,
                '',
                'Test Role'
            )
        };

        Test.startTest();
        HealthCheckGroupVModel healthCheckGroupVModelResult = 
            afflMappingHealthCheckVMapperInstance.getActiveExistingStatusHealthCheckGroupVModel(
                affiliationMappingsModelsList[0],
                new Map<String, PicklistEntryModel>()
            );
        Test.stopTest();

        AffiliationMappingsHCVMapper_TEST.validateHCGroupAssertions(
            healthCheckGroupVModelResult,
            Label.stgHealthCheckAffiliationMappings,
            Label.stgHealthCheckStatusPassed,
            0,
            0,
            0,
            0
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getDuplicateAccountRecordTypeIds returns an
    * empty set when there is no duplicate record type model in Affiliation Mappings
    *****************************************************************************************/
    @isTest 
    private static void getDuplicateAccountRecordTypeIdsNoDuplicate() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Account Record Type', 
                '',
                false,
                '',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping 2',
                'Test Account Record Type 2', 
                '',
                false,
                '',
                'Test Role'
            )
        };
        RecordTypeModel accountRecordTypeModel = 
            new RecordTypeModel(
                '000000000000001234', 
                'Test Account Record Type',
                'Test_Account_Record_Type', 
                true
        );
        RecordTypeModel accountRecordTypeModel2= 
            new RecordTypeModel(
                '000000000000005678', 
                'Test Account Record Type 2',
                'Test_Account_Record_Type2', 
                true
        );
        Map<String, RecordTypeModel> accountRecordTypeModelsByName = new Map<String, RecordTypeModel> {
            'Test_Account_Record_Type' => accountRecordTypeModel,
            'Test_Account_Record_Type2' => accountRecordTypeModel2
        };
        Map<String, RecordTypeModel> accountRecordTypeModelsByLabel = new Map<String, RecordTypeModel> {
            'Test Account Record Type' => accountRecordTypeModel,
            'Test Account Record Type2' => accountRecordTypeModel2
        };


        Test.startTest();
            Set<Id> duplicateAccountRecordTypeIds = afflMappingHealthCheckVMapperInstance.getDuplicateAccountRecordTypeIds(
                affiliationMappingsModelsList, 
                accountRecordTypeModelsByName,
                accountRecordTypeModelsByLabel  
            );
        Test.stopTest();

        System.assertEquals(
            true, 
            duplicateAccountRecordTypeIds.isEmpty(), 
            'The set of duplicate account record type ids should be empty.'
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getDuplicateAccountRecordTypeIds returns a
    * set when there is duplicate record type model in Affiliation Mappings with the same Record Type Value
    *****************************************************************************************/
    @isTest 
    private static void getDuplicateAccountRecordTypeIdsRecordTypeValueSameDuplicate() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Account Record Type', 
                '',
                false,
                '',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping 2',
                'Test Account Record Type', 
                '',
                false,
                '',
                'Test Role'
            )
        };
        RecordTypeModel accountRecordTypeModel = 
            new RecordTypeModel(
                '000000000000001234', 
                'Test Account Record Type',
                'Test_Account_Record_Type', 
                true
        );
        RecordTypeModel accountRecordTypeModel2= 
            new RecordTypeModel(
                '000000000000005678', 
                'Test Account Record Type 2',
                'Test_Account_Record_Type2', 
                true
        );
        Map<String, RecordTypeModel> accountRecordTypeModelsByName = new Map<String, RecordTypeModel> {
            'Test_Account_Record_Type' => accountRecordTypeModel,
            'Test_Account_Record_Type2' => accountRecordTypeModel2
        };
        Map<String, RecordTypeModel> accountRecordTypeModelsByLabel = new Map<String, RecordTypeModel> {
            'Test Account Record Type' => accountRecordTypeModel,
            'Test Account Record Type2' => accountRecordTypeModel2
        };


        Test.startTest();
            Set<Id> duplicateAccountRecordTypeIds = afflMappingHealthCheckVMapperInstance.getDuplicateAccountRecordTypeIds(
                affiliationMappingsModelsList, 
                accountRecordTypeModelsByName,
                accountRecordTypeModelsByLabel  
            );
        Test.stopTest();

        System.assertEquals(
            false, 
            duplicateAccountRecordTypeIds.isEmpty(), 
            'The set of duplicate account record type ids should not be empty.'
        );

        System.assertEquals(
            true, 
            duplicateAccountRecordTypeIds.contains('000000000000001234'), 
            'The set of duplicate account record type ids contains 000000000000001234.'
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getDuplicateAccountRecordTypeIds returns a
    * set when there is duplicate record type model in Affiliation Mappings with the mix Record Type Values
    *****************************************************************************************/
    @isTest 
    private static void getDuplicateAccountRecordTypeIdsRecordTypeValueMixDuplicate() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Account Record Type', 
                '',
                false,
                '',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping 2',
                'Test_Account_Record_Type', 
                '',
                false,
                '',
                'Test Role'
            )
        };
        RecordTypeModel accountRecordTypeModel = 
            new RecordTypeModel(
                '000000000000001234', 
                'Test Account Record Type',
                'Test_Account_Record_Type', 
                true
        );
        RecordTypeModel accountRecordTypeModel2= 
            new RecordTypeModel(
                '000000000000005678', 
                'Test Account Record Type 2',
                'Test_Account_Record_Type2', 
                true
        );
        Map<String, RecordTypeModel> accountRecordTypeModelsByName = new Map<String, RecordTypeModel> {
            'Test_Account_Record_Type' => accountRecordTypeModel,
            'Test_Account_Record_Type2' => accountRecordTypeModel2
        };
        Map<String, RecordTypeModel> accountRecordTypeModelsByLabel = new Map<String, RecordTypeModel> {
            'Test Account Record Type' => accountRecordTypeModel,
            'Test Account Record Type2' => accountRecordTypeModel2
        };


        Test.startTest();
            Set<Id> duplicateAccountRecordTypeIds = afflMappingHealthCheckVMapperInstance.getDuplicateAccountRecordTypeIds(
                affiliationMappingsModelsList, 
                accountRecordTypeModelsByName,
                accountRecordTypeModelsByLabel  
            );
        Test.stopTest();

        System.assertEquals(
            false, 
            duplicateAccountRecordTypeIds.isEmpty(), 
            'The set of duplicate account record type ids should not be empty.'
        );

        System.assertEquals(
            true, 
            duplicateAccountRecordTypeIds.contains('000000000000001234'), 
            'The set of duplicate account record type ids contains 000000000000001234.'
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getDuplicateLookupFieldModelNames returns an
    * empty set when there is no duplicate Lookup Field Model in Affiliation Mappings
    *****************************************************************************************/
    @isTest 
    private static void getDuplicateLookupFieldModelNamesNoDuplicate() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Account Record Type', 
                'Test Contact Primary Field',
                false,
                '',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping 2',
                'Test Account Record Type 2', 
                'Test Contact Primary Field 2',
                false,
                '',
                'Test Role'
            )
        };
        LookupFieldModel lookupFieldModel = 
            new LookupFieldModel( 
                'Test_Contact_Primary_Field',
                'Test Contact Primary Field'
        );
        LookupFieldModel lookupFieldModel2 = 
            new LookupFieldModel( 
                'Test_Contact_Primary_Field2',
                'Test Contact Primary Field 2'
        );
        Map<String, LookupFieldModel> accountLookupsOnContactFieldModelsByName = new Map<String, LookupFieldModel> {
            'Test_Contact_Primary_Field' => lookupFieldModel,
            'Test_Contact_Primary_Field2' => lookupFieldModel2
        };
        Map<String, LookupFieldModel> accountLookupsOnContactFieldModelsByLabel = new Map<String, LookupFieldModel> {
            'Test Contact Primary Field' => lookupFieldModel,
            'Test Contact Primary Field 2' => lookupFieldModel2
        };


        Test.startTest();
            Set<String> duplicateLookupFieldModelNames = afflMappingHealthCheckVMapperInstance.getDuplicateLookupFieldModelNames(
                affiliationMappingsModelsList, 
                accountLookupsOnContactFieldModelsByName,
                accountLookupsOnContactFieldModelsByLabel  
            );
        Test.stopTest();

        System.assertEquals(
            true, 
            duplicateLookupFieldModelNames.isEmpty(), 
            'The set of duplicate lookup field model names should be empty.'
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getDuplicateLookupFieldModelNames returns an
    * set when there is duplicate Lookup Field Model in Affiliation Mappings with the same primary contact field value
    *****************************************************************************************/
    @isTest 
    private static void getDuplicateLookupFieldModelNamesSameDuplicate() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Account Record Type', 
                'Test Contact Primary Field',
                false,
                '',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping 2',
                'Test Account Record Type 2', 
                'Test Contact Primary Field',
                false,
                '',
                'Test Role'
            )
        };
        LookupFieldModel lookupFieldModel = 
            new LookupFieldModel( 
                'Test_Contact_Primary_Field',
                'Test Contact Primary Field'
        );
        LookupFieldModel lookupFieldModel2 = 
            new LookupFieldModel( 
                'Test_Contact_Primary_Field2',
                'Test Contact Primary Field 2'
        );
        Map<String, LookupFieldModel> accountLookupsOnContactFieldModelsByName = new Map<String, LookupFieldModel> {
            'Test_Contact_Primary_Field' => lookupFieldModel,
            'Test_Contact_Primary_Field2' => lookupFieldModel2
        };
        Map<String, LookupFieldModel> accountLookupsOnContactFieldModelsByLabel = new Map<String, LookupFieldModel> {
            'Test Contact Primary Field' => lookupFieldModel,
            'Test Contact Primary Field 2' => lookupFieldModel2
        };


        Test.startTest();
            Set<String> duplicateLookupFieldModelNames = afflMappingHealthCheckVMapperInstance.getDuplicateLookupFieldModelNames(
                affiliationMappingsModelsList, 
                accountLookupsOnContactFieldModelsByName,
                accountLookupsOnContactFieldModelsByLabel  
            );
        Test.stopTest();

        System.assertEquals(
            false, 
            duplicateLookupFieldModelNames.isEmpty(), 
            'The set of duplicate lookup field model names should not be empty.'
        );

        System.assertEquals(
            true, 
            duplicateLookupFieldModelNames.contains('Test_Contact_Primary_Field'), 
            'The set of duplicate lookup field model names should contain Test_Contact_Primary_FieldTest Contact Primary Field.'
        );
    }

    /*****************************************************************************************
    * @description Test method to verify getDuplicateLookupFieldModelNames returns an
    * set when there is duplicate Lookup Field Model in Affiliation Mappings with the mix primary contact field value
    *****************************************************************************************/
    @isTest 
    private static void getDuplicateLookupFieldModelNamesMixDuplicate() {
        AffiliationMappingsHealthCheckVMapper afflMappingHealthCheckVMapperInstance = 
            AffiliationMappingsHealthCheckVMapper.getInstance();

        List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel> {
            new AffiliationMappingsModel(
                'Test Affiliation Mapping',
                'Test Account Record Type', 
                'Test Contact Primary Field',
                false,
                '',
                'Test Role'
            ),
            new AffiliationMappingsModel(
                'Test Affiliation Mapping 2',
                'Test Account Record Type 2', 
                'Test_Contact_Primary_Field',
                false,
                '',
                'Test Role'
            )
        };
        LookupFieldModel lookupFieldModel = 
            new LookupFieldModel( 
                'Test_Contact_Primary_Field',
                'Test Contact Primary Field'
        );
        LookupFieldModel lookupFieldModel2 = 
            new LookupFieldModel( 
                'Test_Contact_Primary_Field2',
                'Test Contact Primary Field 2'
        );
        Map<String, LookupFieldModel> accountLookupsOnContactFieldModelsByName = new Map<String, LookupFieldModel> {
            'Test_Contact_Primary_Field' => lookupFieldModel,
            'Test_Contact_Primary_Field2' => lookupFieldModel2
        };
        Map<String, LookupFieldModel> accountLookupsOnContactFieldModelsByLabel = new Map<String, LookupFieldModel> {
            'Test Contact Primary Field' => lookupFieldModel,
            'Test Contact Primary Field 2' => lookupFieldModel2
        };


        Test.startTest();
            Set<String> duplicateLookupFieldModelNames = afflMappingHealthCheckVMapperInstance.getDuplicateLookupFieldModelNames(
                affiliationMappingsModelsList, 
                accountLookupsOnContactFieldModelsByName,
                accountLookupsOnContactFieldModelsByLabel  
            );
        Test.stopTest();

        System.assertEquals(
            false, 
            duplicateLookupFieldModelNames.isEmpty(), 
            'The set of duplicate lookup field model names should not be empty.'
        );

        System.assertEquals(
            true, 
            duplicateLookupFieldModelNames.contains('Test_Contact_Primary_Field'), 
            'The set of duplicate lookup field model names should contain Test_Contact_Primary_FieldTest Contact Primary Field.'
        );
    }

    /**************************************************************************************
    ********************************* HELPER METHODS **************************************
    **************************************************************************************/

    /**************************************************************************************
    * @description Helper method to validate test assertions for HealthCheckGroup
    **************************************************************************************/ 
    private static void validateHCGroupAssertions(
        HealthCheckGroupVModel healthCheckGroupVModelResult,
        String expectedHealthCheckGroupLabel,
        String expectedHealthCheckGroupStatus,
        Integer expectedPassedChecksCount,
        Integer expectedTotalChecksCount,
        Integer expectedExpandedListSize,
        Integer expectedHealthCheckItemsListSize
    ) {
        System.assertEquals(
            expectedHealthCheckGroupLabel, 
            healthCheckGroupVModelResult.label, 
            'Label should be \'' + expectedHealthCheckGroupLabel + '\'.'
        );

        System.assertEquals(
            expectedHealthCheckGroupStatus, 
            healthCheckGroupVModelResult.status, 
            'Status should be \'' + expectedHealthCheckGroupStatus + '\'.'
        );

        System.assertEquals(
            expectedPassedChecksCount, 
            healthCheckGroupVModelResult.passedChecks, 
            'Passed checks count should be ' + expectedPassedChecksCount + '.'
        );

        System.assertEquals(
            expectedTotalChecksCount, 
            healthCheckGroupVModelResult.totalChecks, 
            'Total checks count should be ' + expectedTotalChecksCount + '.'
        );

        System.assertEquals(
            expectedExpandedListSize, 
            healthCheckGroupVModelResult.expandedRowsList.size(), 
            'ExpandedRows list should have ' + expectedExpandedListSize + ' elements.'
        );

        System.assertEquals(
            expectedHealthCheckItemsListSize, 
            healthCheckGroupVModelResult.healthCheckItemList.size(), 
            'HealthCheckItems list should have ' + expectedHealthCheckItemsListSize + ' elements.'
        );
    }

    /**************************************************************************************
    * @description Helper method to validate test assertions for HealthCheckItem
    **************************************************************************************/ 
    private static void validateHCItemAssertions(
        HealthCheckGroupVModel healthCheckGroupVModelResult,
        String expectedHealthCheckItemSetting,
        String expectedHealthCheckItemStatus,
        String expectedHealthCheckItemStatusLabel,
        String expectedHealthCheckItemDescription,
        String expectedHealthCheckItemFix,
        Integer expectedHealtCheckItemSublistSize
    ) {
        System.assertEquals(
            expectedHealthCheckItemSetting, 
            healthCheckGroupVModelResult.healthCheckItemList[0].setting, 
            'HealthCheckItem setting should be \'' + expectedHealthCheckItemSetting + '\'.'
        );  
        
        System.assertEquals(
            expectedHealthCheckItemStatus, 
            healthCheckGroupVModelResult.healthCheckItemList[0].status, 
            'HealthCheckItem status should be \'' + expectedHealthCheckItemStatus + '\'.'
        ); 

        System.assertEquals(
            expectedHealthCheckItemStatusLabel, 
            healthCheckGroupVModelResult.healthCheckItemList[0].statusLabel, 
            'HealthCheckItem statusLabel should be \'' + expectedHealthCheckItemStatusLabel + '\'.'
        ); 
        
        System.assertEquals(
            expectedHealthCheckItemDescription, 
            healthCheckGroupVModelResult.healthCheckItemList[0].description, 
            'HealthCheckItem statusLabel should be \'' + expectedHealthCheckItemDescription + '\'.'
        ); 

        System.assertEquals(
            expectedHealthCheckItemFix, 
            healthCheckGroupVModelResult.healthCheckItemList[0].recommendedFix, 
            'HealthCheckItem statusLabel should be \'' + expectedHealthCheckItemFix + '\'.'
        ); 

        System.assertEquals(
            expectedHealtCheckItemSublistSize, 
            healthCheckGroupVModelResult.healthCheckItemList[0].healthCheckItemList.size(), 
            'HealthCheckItem statusLabel should be \'' + expectedHealtCheckItemSublistSize + '\'.'
        ); 
    }

    /***************************************************************************
    *********************************STUBS**************************************
    ***************************************************************************/

    /***************************************************************************
    * @description Stub class to simulate the response from
    * AffiliationMappingsHealthCheckVMapper to return a passing result for
    * getAffiliationMappingsHealthCheckResults
    ***************************************************************************/
    private class STUB_AffiliationMappingsHealthCheckVMapperPass extends AffiliationMappingsHealthCheckVMapper {
        private override HealthCheckGroupVModel getValidRecordTypeHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            RecordTypeModel accountRecordTypeModel
        ) {
            return new HealthCheckGroupVModel(
                'Account RT Health Check', 
                'Pass', 
                1, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 1', 
                        'test setting', 
                        'Pass', 
                        Label.stgHealthCheckStatusPassed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getAccountRecordTypeUniquenessHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            RecordTypeModel accountRecordTypeModel,
            Set<Id> duplicateAccountRecordTypeIds
        ) {
            return new HealthCheckGroupVModel(
                'Account RT Uniqueness Health Check', 
                'Pass', 
                1, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 2', 
                        'test setting', 
                        'Pass', 
                        Label.stgHealthCheckStatusPassed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getValidContactPrimaryFieldHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            LookupFieldModel accountlookupFieldOnContactFieldModelFromName
        ) {
            return new HealthCheckGroupVModel(
                'Contact Primary Field Health Check', 
                'Pass', 
                1, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 3', 
                        'test setting', 
                        'Pass', 
                        Label.stgHealthCheckStatusPassed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getContactPrimaryFieldUniquenessHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            LookupFieldModel accountlookupFieldOnContactFieldModel,
            Set<String> duplicateLookupFieldModelNames
        ) {
            return new HealthCheckGroupVModel(
                'Contact Primary Field Uniqueness Health Check', 
                'Pass', 
                1, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 4', 
                        'test setting', 
                        'Pass', 
                        Label.stgHealthCheckStatusPassed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getActiveExistingRoleHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return new HealthCheckGroupVModel(
                'Contact Primary Field Health Check', 
                'Pass', 
                1, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 5', 
                        'test setting', 
                        'Pass', 
                        Label.stgHealthCheckStatusPassed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getActiveExistingStatusHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return new HealthCheckGroupVModel(
                'Contact Primary Field Health Check', 
                'Pass', 
                1, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 6', 
                        'test setting', 
                        'Pass', 
                        Label.stgHealthCheckStatusPassed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * AffiliationMappingsHealthCheckVMapper to return a failing result for
    * getAffiliationMappingsHealthCheckResults
    ***************************************************************************/
    private class STUB_AffiliationMappingsHealthCheckVMapperFail extends AffiliationMappingsHealthCheckVMapper {
        private override HealthCheckGroupVModel getValidRecordTypeHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            RecordTypeModel accountRecordTypeModel
        ) {
            return new HealthCheckGroupVModel(
                'Account RT Health Check', 
                'Fail', 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 1', 
                        'test setting', 
                        'Fail', 
                        Label.stgHealthCheckStatusFailed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getAccountRecordTypeUniquenessHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            RecordTypeModel accountRecordTypeModel,
            Set<Id> duplicateAccountRecordTypeIds
        ) {
            return new HealthCheckGroupVModel(
                'Account RT Uniqueness Health Check', 
                'Fail', 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 2', 
                        'test setting', 
                        'Fail', 
                        Label.stgHealthCheckStatusFailed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getValidContactPrimaryFieldHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            LookupFieldModel accountlookupFieldOnContactFieldModelFromName
        ) {
            return new HealthCheckGroupVModel(
                'Contact Primary Field Health Check', 
                'Fail', 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 3', 
                        'test setting', 
                        'Fail', 
                        Label.stgHealthCheckStatusFailed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getContactPrimaryFieldUniquenessHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            LookupFieldModel accountlookupFieldOnContactFieldModel,
            Set<String> duplicateLookupFieldModelNames
        ) {
            return new HealthCheckGroupVModel(
                'Contact Primary Field Uniqueness Health Check', 
                'Fail', 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 4', 
                        'test setting', 
                        'Fail', 
                        Label.stgHealthCheckStatusFailed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getActiveExistingRoleHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return new HealthCheckGroupVModel(
                'Auto Enrollment Role Health Check', 
                'Fail', 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 5', 
                        'test setting', 
                        'Fail', 
                        Label.stgHealthCheckStatusFailed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }

        private override HealthCheckGroupVModel getActiveExistingStatusHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return new HealthCheckGroupVModel(
                'Auto Enrollment Status Health Check', 
                'Fail', 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>{
                    new HealthCheckItemVModel(
                        'test key 6', 
                        'test setting', 
                        'Fail', 
                        Label.stgHealthCheckStatusFailed,
                        'test description', 
                        'test fix',
                        new List<HealthCheckItemVModel>()
                    ) 
                }
            );
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * AffiliationMappingsHealthCheckVMapper to control individual health check methods
    * for failure
    ***************************************************************************/
    private class STUB_AffiliationMappingsHealthCheckVMapperSubFail extends AffiliationMappingsHealthCheckVMapper {
        private override HealthCheckGroupVModel getValidRecordTypeHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingModel, 
            RecordTypeModel accountRecordTypeModel
        ) {
            return new HealthCheckGroupVModel(
                'Failed Health Check 1', 
                Label.stgHealthCheckStatusFailed, 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>()
            );
        }

        private override HealthCheckGroupVModel getAccountRecordTypeUniquenessHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingModel, 
            RecordTypeModel accountRecordTypeModel,
            Set<Id> duplicateAccountRecordTypeIds
        ) {
            return new HealthCheckGroupVModel(
                'Failed Health Check 2', 
                Label.stgHealthCheckStatusFailed, 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>()
            );
        }

        private override HealthCheckGroupVModel getValidContactPrimaryFieldHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            LookupFieldModel accountlookupFieldOnContactFieldModelFromName
        ) {
            return new HealthCheckGroupVModel(
                'Failed Health Check 3', 
                Label.stgHealthCheckStatusFailed, 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>()
            );
        }

        private override HealthCheckGroupVModel getContactPrimaryFieldUniquenessHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingModel, 
            LookupFieldModel accountlookupFieldOnContactFieldModel,
            Set<String> duplicateLookupFieldModelNames
        ) {
            return new HealthCheckGroupVModel(
                'Failed Health Check 4', 
                Label.stgHealthCheckStatusFailed, 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>()
            );
        }

        private override HealthCheckGroupVModel getActiveExistingRoleHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return new HealthCheckGroupVModel(
                'Failed Health Check 5', 
                Label.stgHealthCheckStatusFailed, 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>()
            );
        }

        private override HealthCheckGroupVModel getActiveExistingStatusHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return new HealthCheckGroupVModel(
                'Failed Health Check 6', 
                Label.stgHealthCheckStatusFailed, 
                0, 
                1, 
                new List<String>(), 
                new List<HealthCheckItemVModel>()
            );
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * AffiliationMappingsHealthCheckVMapper to control individual health check methods
    * for success
    ***************************************************************************/
    private class STUB_AffiliationMappingsHealthCheckVMapperSub extends AffiliationMappingsHealthCheckVMapper {
        private override HealthCheckGroupVModel getValidRecordTypeHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            RecordTypeModel accountRecordTypeModel
        ) {
            return this.mockCheck(affiliationMappingsModel);
        }

        private override HealthCheckGroupVModel getValidContactPrimaryFieldHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel, 
            LookupFieldModel accountlookupFieldOnContactFieldModelFromName
        ) {
            return this.mockCheck(affiliationMappingsModel);
        }

        private override HealthCheckGroupVModel getActiveExistingRoleHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return this.mockCheck(affiliationMappingsModel);
        }

        private override HealthCheckGroupVModel getActiveExistingStatusHealthCheckGroupVModel(
            AffiliationMappingsModel affiliationMappingsModel,
            Map<String, PicklistEntryModel> picklistEntryModelByName
        ) {
            return this.mockCheck(affiliationMappingsModel);
        }
        
        private HealthCheckGroupVModel mockCheck(AffiliationMappingsModel affiliationMappingModel) {
            HealthCheckGroupVModel healthCheckGroupVModel = new HealthCheckGroupVModel(
                '',
                '',
                0,
                0,
                new List<String>(),
                new List<HealthCheckItemVModel>()
            );
    
            HealthCheckItemVModel healthCheckItemVModel =
                new healthCheckItemVModel(
                    'Mock',
                    'MockSetting',
                    'Pass',
                    'MockStatusLabel',
                    'MockDescription',
                    'MockRecommendedFix',
                    new List<HealthCheckItemVModel>()
                );

            healthCheckGroupVModel.totalChecks += 1;

            if(affiliationMappingModel != null) {
                healthCheckGroupVModel.passedChecks += 1;
            }

            if(healthCheckGroupVModel.passedChecks < healthCheckGroupVModel.totalChecks) {
                healthCheckItemVModel.status = 'Fail';
                healthCheckItemVModel.statusLabel = Label.stgHealthCheckStatusFailed;
            }
    
            healthCheckGroupVModel.healthCheckItemList.add(healthCheckItemVModel);
            return healthCheckGroupVModel;
        }
    }

    private class STUB_LookupFieldService extends LookupFieldService {
        public override Map<String, LookupFieldModel> getModelByNameMapForSObjectType(
            SObjectType sObjectType, 
            SObjectType lookupToSObjectType
        ) {
            return new Map<String, LookupFieldModel>{
                'Test_Field__c' => new LookupFieldModel(
                    'Test_Field__c',
                    'Test Field'
                )
            };
        }
    }

    private class STUB_PicklistEntryServiceRole extends PickListEntryService {
        public override Map<String,PicklistEntryModel> getModelsByNameForSObjectField(
            SObjectType sObjectTypeName,
            SObjectField SObjectFieldName
        ) {
            return new Map<String, PicklistEntryModel>{
                'Test_Role' => new PicklistEntryModel(
                    'Test_Role',
                    'Test Role', 
                    true)
            };
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * AffiliationMappingsService to return a predetermined set of models.
    ***************************************************************************/
    private class STUB_AffiliationMappingsService extends AffiliationMappingsService {
        public override List<AffiliationMappingsModel> getAffiliationMappingsModels() {
            List<AffiliationMappingsModel> AffiliationMappingsModelList =
                new List<AffiliationMappingsModel>();
            
            AffiliationMappingsModel AffiliationMappingsModel = 
                new AffiliationMappingsModel(
                    'testName',
                    'test account record type name',
                    'testPrimaryAfflField',
                    true,
                    'testStatus',
                    'testRole'
                );

            AffiliationMappingsModelList.add(AffiliationMappingsModel);

            return AffiliationMappingsModelList;
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * AffiliationMappingsService to return a predetermined set of unfound
    * models.
    ***************************************************************************/
    private class STUB_AffiliationMappingsServiceUnfound extends AffiliationMappingsService {
        public override List<AffiliationMappingsModel> getAffiliationMappingsModels() {
            List<AffiliationMappingsModel> affiliationMappingsModelsList = new List<AffiliationMappingsModel>();

            affiliationMappingsModelsList.add(
                new AffiliationMappingsModel(
                    'unfound name',
                    'unfound accountRecordTypeFieldValue',
                    'unfound primaryAffiliationField',
                    true,
                    'unfound autoProgramEnrollmentStatus',
                    'unfound autoProgramEnrollmentRole'
                )
            );

            return affiliationMappingsModelsList;
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * RecordTypeService to return a predetermined set of active models.
    ***************************************************************************/
    private class STUB_RecordTypeService extends RecordTypeService {
        public override Map<Id, RecordTypeModel> getModelByIdMapForSObjectType(Schema.SObjectType sObjectType) {
            Map<Id, RecordTypeModel> recordTypeModelById =
                new Map<Id, RecordTypeModel>();
            
            recordTypeModelById.put('000000000000000001', new RecordTypeModel(
                '000000000000000001',
                'Active RecordType Test Name1',
                'activeRTTestDeveloperName1',
                true
            ));         
                 
            recordTypeModelById.put('000000000000000002', new RecordTypeModel(
                '000000000000000002',
                'Active RecordType Test Name2',
                'activeRTTestDeveloperName2',
                true
            ));         

            recordTypeModelById.put('000000000000000003', new RecordTypeModel(
                '000000000000000003',
                'Active RecordType Test Name3',
                'activeRTTestDeveloperName3',
                true
            ));         
            
            return recordTypeModelById;
        }

        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            return new RecordTypeModel(
                '000000000000000006',
                'Active RecordType Name',
                'activeRTDevName',
                true
            );
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * RecordTypeService to return a predetermined set of inactive models.
    ***************************************************************************/
    private class STUB_RecordTypeServiceInactive extends RecordTypeService {
        public override Map<Id, RecordTypeModel> getModelByIdMapForSObjectType(Schema.SObjectType sObjectType) {
            Map<Id, RecordTypeModel> recordTypeModelById =
                new Map<Id, RecordTypeModel>();
            
            recordTypeModelById.put('000000000000000001', new RecordTypeModel(
                '000000000000000001',
                'Inactive RecordType Test Name1',
                'InactiveRTTestDeveloperName1',
                false
            ));         
                 
            recordTypeModelById.put('000000000000000002', new RecordTypeModel(
                '000000000000000002',
                'Inactive RecordType Test Name2',
                'InactiveRTTestDeveloperName2',
                false
            ));         

            recordTypeModelById.put('000000000000000003', new RecordTypeModel(
                '000000000000000003',
                'Inactive RecordType Test Name3',
                'InactiveRTTestDeveloperName3',
                false
            ));         
            
            return recordTypeModelById;
        }

        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            return new RecordTypeModel(
                '000000000000000005',
                'Inactive RecordType Name',
                'inactiveRTDevName',
                false
            );
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * RecordTypeService to return a null value.
    ***************************************************************************/
    private class STUB_RecordTypeServiceNull extends RecordTypeService {
        public override RecordTypeModel getRecordTypeModelFromMap(String recordTypeId, Map<Id, RecordTypeModel> recordTypeModelById) { 
            return null;
        }

        public override Map<Id, RecordTypeModel> getModelByIdMapForSObjectType(Schema.SObjectType sObjectType) {
            return new Map<Id, RecordTypeModel>{
               '000000000000000009' => new RecordTypeModel(
                                            '000000000000000009',
                                            'random test acct record type',
                                            'randomAcctRT',
                                            true
                                       )
            };
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * LookupFieldService to return a valid lookup field model for a Contact
    * field that is a lookup to Account matching my field dev name.
    ***************************************************************************/
    private class STUB_LookupFieldServiceDevNameMatch extends LookupFieldService {
        public override LookupFieldModel getLookupFieldModelFromNameMap(
            String fieldName, 
            Map<String, LookupFieldModel> lookupFieldModelByName
        ){
            return new LookupFieldModel(
                'Valid Contact Lookup Field Name',
                'Valid Contact Lookup Field Label'
            );
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * LookupFieldService to return a valid lookup field model for a Contact
    * field that is a lookup to Account matching my field label name.
    ***************************************************************************/
    private class STUB_LookupFieldServiceLabelMatch extends LookupFieldService {
        public override LookupFieldModel getLookupFieldModelFromNameMap(
            String fieldName, 
            Map<String, LookupFieldModel> lookupFieldModelByName 
        ){
            return null;
        }
        
        public override LookupFieldModel getLookupFieldModelFromLabelMap(
            String fieldLabel, 
            Map<String, LookupFieldModel> lookupFieldModelByLabel) 
        {
            return new LookupFieldModel(
                'Valid Contact Lookup Field Name',
                'Valid Contact Lookup Field Label'
            );
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from
    * LookupFieldService to return a null value.
    ***************************************************************************/
    private class STUB_LookupFieldServiceNull extends LookupFieldService {
        public override LookupFieldModel getLookupFieldModelFromNameMap(
            String fieldName, 
            Map<String, LookupFieldModel> lookupFieldModelByName) 
        {
            return null;
        }

        public override LookupFieldModel getLookupFieldModelFromLabelMap(
            String fieldLabel, 
            Map<String, LookupFieldModel> lookupFieldModelByLabel) 
        {
            return null;
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from PicklistEntryService
    * to return a PicklistEntryModel for a valid and active picklist value.
    ***************************************************************************/
    private class STUB_PicklistEntryServiceValid extends PicklistEntryService {
        public override Map<String,PicklistEntryModel> getModelsByNameForSObjectField(
            SObjectType sObjectTypeName,
            SObjectField SObjectFieldName
        ) {
            return new Map<String,PicklistEntryModel>{
                'Test Auto Enrollment Name' => new PicklistEntryModel(
                'Test Auto Enrollment Name',
                'Auto Enrollment Label',
                true)
            };
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from PicklistEntryService
    * to return a PicklistEntryModel for a valid, but inactive picklist value.
    ***************************************************************************/
    private class STUB_PicklistEntryServiceInactive extends PicklistEntryService {
        public override Map<String,PicklistEntryModel> getModelsByNameForSObjectField(
            SObjectType sObjectTypeName,
            SObjectField SObjectFieldName
        ) {
            return new Map<String,PicklistEntryModel>{
                'Test Auto Enrollment Name' => new PicklistEntryModel(
                'Test Auto Enrollment Name',
                'Auto Enrollment Label',
                false)
            };
        }
    }

    /***************************************************************************
    * @description Stub class to simulate the response from PicklistEntryService 
    * to return a null value.
    ***************************************************************************/
    private class STUB_PicklistEntryServiceNull extends PicklistEntryService {
        public override Map<String,PicklistEntryModel> getModelsByNameForSObjectField(
            SObjectType sObjectTypeName,
            SObjectField SObjectFieldName
        ) {
            return null;
        }
    }
}
