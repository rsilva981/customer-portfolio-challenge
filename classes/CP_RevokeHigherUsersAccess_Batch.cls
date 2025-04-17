public class CP_RevokeHigherUsersAccess_Batch implements Database.Batchable<SObject> {
    
  	public CP_RoleHierarchy_Helper helper;
    public Set<Id> managers;
    
    public CP_RevokeHigherUsersAccess_Batch(){
        this.helper = new CP_RoleHierarchy_Helper();
        this.managers = helper.getAllManagers();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([ 
            SELECT Id, Source__c, Sub_Source__c, Content_Details__c
            FROM Debug_Log__c 
            WHERE Source__c = 'Customer Portfolios' AND Sub_Source__c = 'Revoke' AND Success__c = false
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Debug_Log__c> logs) {
        Customer_Portfolio__c[] customerPortfolios = getLogPortfolios( logs );
        
        Map<String, Customer_Portfolio__c> cpKeys = new Map<String, Customer_Portfolio__c>();
        Set<Id> userIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        
        for( Customer_Portfolio__c cp : customerPortfolios ){
            Set<Id> highUsers = helper.getManagers( cp.User__c );
            if( !highUsers.isEmpty() ){ //This user is sub, so we need to check if the managers has access
                for( Id highUserId : highUsers ){
                    userIds.add( highUserId );
                    contactIds.add( cp.Contact__c );
                    
                    String key = helper.buildKey( highUserId, cp.Contact__c );
                    cpKeys.put( key, cp); 
                }
            } else {
                //What to do when a manager access is deleted?
            }
        }
        
        Map<String, Customer_Portfolio__c> existingPortfoliosMap = getExistingPortfoliosMap( userIds, contactIds );
        Customer_Portfolio__c[] portfoliosToDelete = getPortfoliosToDelete( cpKeys, existingPortfoliosMap );
        
        delete portfoliosToDelete;
        validateLogs( logs );
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('CP_RevokeHigherUsersAccess_Batch Ended');
    }
    
    private Customer_Portfolio__c[] getPortfoliosToDelete( Map<String, Customer_Portfolio__c> cpKeys, Map<String, Customer_Portfolio__c> existingPortfoliosMap ){
        Customer_Portfolio__c[] portfoliosToDelete = new List<Customer_Portfolio__c>();
        for( String key : cpKeys.keySet() ){
            System.debug(key);
            if( existingPortfoliosMap.containsKey(key) ){ //A manager user has access to this Customer Portfolio, so we need to delete
                Customer_Portfolio__c portfolioToDelete = existingPortfoliosMap.get( key );
                System.debug('Delete this: ' + portfolioToDelete);
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