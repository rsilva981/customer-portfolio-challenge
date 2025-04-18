public class CP_GrantHigherUsersAccess_Batch implements Database.Batchable<SObject>, Database.Stateful {
    
    //Batch job to grant Customer Portfolio access to users higher in the role hierarchy whenever lower-level users are granted access
    
    public CP_RoleHierarchy_Helper helper;
    
    public CP_GrantHigherUsersAccess_Batch(){
        this.helper = new CP_RoleHierarchy_Helper();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, User__c, Contact__c, Source__c, External_Id__c, Favorite__c
            FROM Customer_Portfolio__c
            WHERE Source__c = 'External' AND CreatedDate = LAST_N_DAYS:10
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Customer_Portfolio__c> scope) {

        Map<String, Customer_Portfolio__c> cpKeys = new Map<String, Customer_Portfolio__c>();
        Set<Id> userIds = new Set<Id>();
        Set<Id> contactIds= new Set<Id>(); 
        
        for( Customer_Portfolio__c cp : scope ){
            Set<Id> highUsers = helper.userToManagersMap.get(cp.User__c);
            if( !highUsers.isEmpty() ){
                for( Id highUserId : highUsers ){
                    userIds.add( highUserId );
                    contactIds.add( cp.Contact__c );
                    
                    String key = helper.buildKey( highUserId, cp.Contact__c );
                    cpKeys.put( key, cp); 
                }
            }
        }
        
        Set<String> existingPortfoliosSet = getExistingPortfoliosSet( userIds, contactIds );
        Customer_Portfolio__c[] portfolioToInsert = getPortfoliosToInsert( cpKeys, existingPortfoliosSet );
        
        Database.SaveResult[] sr = Database.insert( portfolioToInsert, false);
        helper.handleSaveResult( sr );
    }

    public void finish(Database.BatchableContext bc) {
        Database.executeBatch( new CP_RevokeHigherUsersAccess_Batch() );
    }
    
    private Set<String> getExistingPortfoliosSet( Set<Id> userIds, Set<Id> contactIds ){
		Set<String> existingIds = new Set<String>();
    
        for (Customer_Portfolio__c cp : [ SELECT External_Id__c
                                          FROM Customer_Portfolio__c
                                          WHERE User__c IN: userIds
                                          AND Contact__c IN: contactIds ]) {
            existingIds.add(cp.External_Id__c);
        }
        
        return existingIds;
    }
    
    private Customer_Portfolio__c[] getPortfoliosToInsert( Map<String, Customer_Portfolio__c> cpKeys, Set<String> existingPortfoliosSet ){
        Customer_Portfolio__c[] portfoliosToInsert = new List<Customer_Portfolio__c>();

        for( String key : cpKeys.keySet() ){
            Customer_Portfolio__c portfolioToUse = cpKeys.get( key );
            if( !existingPortfoliosSet.contains( key ) ){
                Id highUserId = key.substringBefore('.');
                Customer_Portfolio__c newPortfolio = builPortfolio( highUserId, portfolioToUse);
               	portfoliosToInsert.add( newPortfolio );
            }
        }

        return portfoliosToInsert;
    }
    
    private Customer_Portfolio__c builPortfolio( Id highUserId, Customer_Portfolio__c portfolioToUse){
        return  new Customer_Portfolio__c(
            User__c = highUserId,
            Contact__c = portfolioToUse.Contact__c,
            Source__c = 'Internal',
            External_Id__c = helper.buildKey(highUserId, portfolioToUse.Contact__c),
            Favorite__c = portfolioToUse.Favorite__c
        );
    }
}