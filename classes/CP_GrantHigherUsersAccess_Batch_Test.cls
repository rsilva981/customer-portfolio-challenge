@isTest
private class CP_GrantHigherUsersAccess_Batch_Test {

    @testSetup
    static void setupData() {
        // Step 1: Create User Roles
        UserRole lowerRole = new UserRole(Name = 'Support Rep');
        insert lowerRole;

        UserRole upperRole = new UserRole(Name = 'Support Manager', ParentRoleId = lowerRole.Id);
        insert upperRole;

        // Step 2: Create Users in separate DML context
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User lowerUser = new User(
            FirstName = 'Lower',
            LastName = 'User',
            Alias = 'luser',
            Email = 'lower@example.com',
            Username = 'loweruser' + DateTime.now().getTime() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            UserRoleId = lowerRole.Id
        );

        User managerUser = new User(
            FirstName = 'Manager',
            LastName = 'User',
            Alias = 'muser',
            Email = 'manager@example.com',
            Username = 'manageruser' + DateTime.now().getTime() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            UserRoleId = upperRole.Id
        );

        insert new List<User>{ lowerUser, managerUser };

    }

    @isTest
    static void testManagerAccessIsGranted() {
        buildCustomObjects();
        
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Customer' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE FirstName = 'Manager' LIMIT 1];

        Test.startTest();
        Database.executeBatch(new CP_GrantHigherUsersAccess_Batch(), 1);
        Test.stopTest();

        List<Customer_Portfolio__c> results = [
            SELECT Id, User__c, Contact__c, Source__c
            FROM Customer_Portfolio__c
            WHERE User__c = :manager.Id AND Contact__c = :testContact.Id AND Source__c = 'Internal'
        ];

        System.assertEquals(1, results.size(), 'Manager should have inherited Internal Customer Portfolio access.');
    }
    
    private static void buildCustomObjects(){
        User lowerUser = [SELECT ID FROM User WHERE email = 'lower@example.com'];

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Customer');
        insert contact;

        Customer_Portfolio__c cp = new Customer_Portfolio__c(
            User__c = lowerUser.Id,
            Contact__c = contact.Id,
            Source__c = 'External',
            External_Id__c = lowerUser.Id + '.' + contact.Id,
            Favorite__c = false
        );
        insert cp;
    }
}