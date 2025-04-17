public class CP_CustomerPortfolio_Handler {

    public static void handleAfterInsert(List<Customer_Portfolio__c> newRecords) {

    }

    public static void handleAfterDelete(List<Customer_Portfolio__c> oldRecords) {
		handlePermissionsDeletion( oldRecords );
    }
    
    private static void handlePermissionsDeletion(List<Customer_Portfolio__c> oldRecords){
        Debug_Log__c[] logsToInsert = new List<Debug_Log__c>();
        for( Customer_Portfolio__c cp : oldRecords ){
            //TODO Add conditions to check if it was deleted by 3rd party, if so, create log
            logsToInsert.add( new Debug_Log__c(
            	Source__c = 'Customer Portfolios', //TODO Change API value name to "CustomerPortfolios"
                Sub_Source__c = 'Revoke',
                Content_Details__c = JSON.serialize(cp),
                Success__c = false
            ));
        }
        
        insert logsToInsert; //TODO Use Platform Events to insert the logs
    }
}
