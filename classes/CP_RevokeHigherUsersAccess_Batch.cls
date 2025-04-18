public class CP_RevokeHigherUsersAccess_Batch implements Database.Batchable<SObject> {
    
    // Batch job to handle revoking access from the 3rd party and check whether the system needs to create or delete Customer Portfolios based on the hierarchy
    
  	public CP_RoleHierarchy_Helper helper;
    
    public CP_RevokeHigherUsersAccess_Batch(){
        this.helper = new CP_RoleHierarchy_Helper();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([ 
            SELECT Id, Source__c, Sub_Source__c, Content_Details__c
            FROM Debug_Log__c 
            WHERE Source__c = 'Customer Portfolios' AND Sub_Source__c = 'Revoke' AND Success__c = false
        ]); 
    }

    public void execute(Database.BatchableContext bc, List<Debug_Log__c> logs) { //TODO Implement try catch system
        Customer_Portfolio__c[] customerPortfolios = getLogPortfolios( logs );
        
        Map<String, Customer_Portfolio__c> cpManKeys = new Map<String, Customer_Portfolio__c>(); //Manager access
        Map<String, Customer_Portfolio__c> cpSubsKeys = new Map<String, Customer_Portfolio__c>(); //Subs access
        Set<Id> userIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        
        for( Customer_Portfolio__c cp : customerPortfolios ){
            contactIds.add( cp.Contact__c );
            Set<Id> highUsers = helper.userToManagersMap.get( cp.User__c );
            if( !highUsers.isEmpty() ){ //This user is sub, so we need to check if the managers has access
                userIds.addAll(highUsers);
                for( Id highUserId : highUsers ){
                    String key = helper.buildKey( highUserId, cp.Contact__c );
                    cpManKeys.put( key, cp); 
                }
            } else { //This user is a manager, we need to check if the subs have access
                Set<Id> subUsers = helper.userToSubordinatesMap.get( cp.User__c );
                if( !subUsers.isEmpty() ){ //Since it's a manager, if 1 sub has access to the Customer Profile, the manager should have also
                    Id subUserId = new List<Id>(subUsers)[0];
                    String key = helper.buildKey( subUserId, cp.Contact__c );
                    cpSubsKeys.put( key, cp );
                    userIds.add( subUserId );
                }
            }
        } 
        
        Map<String, Customer_Portfolio__c> existingPortfoliosMap = getExistingPortfoliosMap( userIds, contactIds );
        
        Customer_Portfolio__c[] portfoliosToDelete = getPortfoliosToDelete( cpManKeys, existingPortfoliosMap );
        Database.DeleteResult[] dr = Database.delete( portfoliosToDelete, false);
        helper.handleDeleteResult( dr );
        
        Customer_Portfolio__c[] portfoliosToInsert = getPortfoliosToInsert( cpSubsKeys, existingPortfoliosMap );
        Database.SaveResult[] sr = Database.insert( portfoliosToInsert, false);
        helper.handleSaveResult( sr );
        
        validateLogs( logs );
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('CP_RevokeHigherUsersAccess_Batch Ended');
    }
    
    private Customer_Portfolio__c[] getPortfoliosToInsert(  Map<String, Customer_Portfolio__c> cpSubsKeys, Map<String, Customer_Portfolio__c> existingPortfoliosMap ){
        Customer_Portfolio__c[] portfoliosToCreate = new List<Customer_Portfolio__c>();
        for( String key : cpSubsKeys.keySet() ){
            if( existingPortfoliosMap.containsKey(key) ){ //A sub user has access to this Customer Portfolio, so we need to create one for the Manager
                Customer_Portfolio__c portfolioToCreate = cpSubsKeys.get( key ).clone(false, true, false, false);
                portfolioToCreate.Source__c = 'Internal';
                portfoliosToCreate.add( portfolioToCreate );
            }
        }
        
        return portfoliosToCreate;
    }
    
    private Customer_Portfolio__c[] getPortfoliosToDelete( Map<String, Customer_Portfolio__c> cpKeys, Map<String, Customer_Portfolio__c> existingPortfoliosMap ){
        Customer_Portfolio__c[] portfoliosToDelete = new List<Customer_Portfolio__c>();
        for( String key : cpKeys.keySet() ){
            if( existingPortfoliosMap.containsKey(key) ){ //A manager user has access to this Customer Portfolio, so we need to delete
                Customer_Portfolio__c portfolioToDelete = existingPortfoliosMap.get( key );
                portfoliosToDelete.add( portfolioToDelete );
            }
        }
        
        return portfoliosToDelete;
    }
  
    private Map<String, Customer_Portfolio__c> getExistingPortfoliosMap( Set<Id> userIds, Set<Id> contactIds ){
		Map<String, Customer_Portfolio__c> existingPortfolios = new Map<String, Customer_Portfolio__c>();
    
        for (Customer_Portfolio__c cp : [ SELECT External_Id__c
                                          FROM Customer_Portfolio__c
                                          WHERE User__c IN: userIds
                                          AND Contact__c IN: contactIds
                                          AND Source__c = 'Internal'
                                        ]) {
            existingPortfolios.put(cp.External_Id__c, cp);
        }
        
        return existingPortfolios;
    }
    
    private Customer_Portfolio__c[] getLogPortfolios( Debug_Log__c[] logs ){
        Customer_Portfolio__c[] customerPortfolios = new List<Customer_Portfolio__c>();
        for( Debug_Log__c log : logs ){
            Customer_Portfolio__c cp = (Customer_Portfolio__c) JSON.deserialize(log.Content_Details__c, Customer_Portfolio__c.class);
            customerPortfolios.add( cp );
        }
        
        return customerPortfolios;
    }
    
    private void validateLogs( Debug_Log__c[] logs ){
        for(Debug_Log__c log : logs ){
            log.Success__c = true;
        }
        
        update logs;
    }
}