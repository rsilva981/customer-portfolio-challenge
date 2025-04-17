trigger CustomerPortfolioTrigger on Customer_Portfolio__c (after insert, after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            CP_CustomerPortfolio_Handler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isDelete) {
            CP_CustomerPortfolio_Handler.handleAfterDelete(Trigger.old);
        }
    }
}