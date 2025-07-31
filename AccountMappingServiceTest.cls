@isTest
public class AccountMappingServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Create group accounts (parent accounts)
        List<Account> groupAccounts = new List<Account>{
            new Account(
                Name = 'Group Account 1',
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_GROUP_ACCOUNT,
                Order_Form_Anchor__c = true,
                Order_Form_Status__c = c.ORDER_FORM_COMPLETED,
                Australian_Business_Number__c = 'ABN123456789',
                Tax_Account_Number__c = 'TAX123456'
            ),
            new Account(
                Name = 'Group Account 2',
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_GROUP_ACCOUNT,
                Order_Form_Anchor__c = true,
                Order_Form_Status__c = c.ORDER_FORM_COMPLETED,
                Australian_Business_Number__c = 'ABN987654321',
                Tax_Account_Number__c = 'TAX987654'
            )
        };
        insert groupAccounts;
        
        // Create anchor physical location accounts
        List<Account> anchorPhysicalLocations = new List<Account>{
            new Account(
                Name = 'Anchor Physical Location 1',
                ParentId = groupAccounts[0].Id,
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION,
                Order_Form_Anchor__c = true,
                Order_Form_Status__c = c.ORDER_FORM_COMPLETED,
                Australian_Business_Number__c = 'ABN123456789',
                Tax_Account_Number__c = 'TAX123456'
            ),
            new Account(
                Name = 'Anchor Physical Location 2',
                ParentId = groupAccounts[1].Id,
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION,
                Order_Form_Anchor__c = true,
                Order_Form_Status__c = c.ORDER_FORM_COMPLETED,
                Australian_Business_Number__c = 'ABN987654321',
                Tax_Account_Number__c = 'TAX987654'
            )
        };
        insert anchorPhysicalLocations;
        
        // Create regular physical location accounts (to be mapped)
        List<Account> physicalLocations = new List<Account>{
            new Account(
                Name = 'Physical Location with ABN',
                ParentId = groupAccounts[0].Id,
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION,
                Order_Form_Anchor__c = false,
                Order_Form_Status__c = c.CLONE_ORDER_FORM,
                Australian_Business_Number__c = 'ABN123456789'
            ),
            new Account(
                Name = 'Physical Location with Tax',
                ParentId = groupAccounts[1].Id,
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION,
                Order_Form_Anchor__c = false,
                Order_Form_Status__c = c.CLONE_ORDER_FORM,
                Tax_Account_Number__c = 'TAX987654'
            ),
            new Account(
                Name = 'Physical Location with NA ABN',
                ParentId = groupAccounts[0].Id,
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION,
                Order_Form_Anchor__c = false,
                Order_Form_Status__c = c.CLONE_ORDER_FORM,
                Australian_Business_Number__c = 'NA',
                Tax_Account_Number__c = 'TAX123456'
            )
        };
        insert physicalLocations;
    }
    
    @isTest
    static void testMapAccountsToAnchorAccounts() {
        List<Account> physicalLocations = [
            SELECT Id, Name, ParentId, Australian_Business_Number__c, Tax_Account_Number__c, 
                   Order_Form_Status__c, Record_Type_Developer_Name__c
            FROM Account 
            WHERE Order_Form_Anchor__c = false
        ];
        
        Test.startTest();
        Map<Id, Account> result = AccountMappingService.mapAccountsToAnchorAccounts(
            physicalLocations, 
            c.ADDITIONAL_LOCATION
        );
        Test.stopTest();
        
        System.assertEquals(3, result.size(), 'All physical locations should be mapped');
        
        // Verify all mapped accounts are anchors
        for (Account anchor : result.values()) {
            System.assertEquals(true, anchor.Order_Form_Anchor__c, 'Should map to anchor accounts only');
            System.assertEquals(c.ORDER_FORM_COMPLETED, anchor.Order_Form_Status__c, 'Anchor should have completed status');
        }
    }
    
    @isTest
    static void testBuildGroupAnchorMap() {
        List<Account> groupAccounts = [
            SELECT Id FROM Account WHERE Record_Type_Developer_Name__c = :c.ACCOUNT_RT_GROUP_ACCOUNT
        ];
        
        Set<Id> groupAccountIds = new Set<Id>();
        for (Account acc : groupAccounts) {
            groupAccountIds.add(acc.Id);
        }
        
        Set<String> brnNumbers = new Set<String>{'ABN123456789', 'ABN987654321'};
        Set<String> taxNumbers = new Set<String>{'TAX123456', 'TAX987654'};
        
        Test.startTest();
        Map<Id, Set<String>> result = AccountMappingService.buildGroupAnchorMap(
            groupAccountIds, 
            brnNumbers, 
            taxNumbers
        );
        Test.stopTest();
        
        System.assert(!result.isEmpty(), 'Should return group anchor mappings');
        
        // Verify the structure
        for (Id groupId : result.keySet()) {
            Set<String> identifiers = result.get(groupId);
            System.assert(!identifiers.isEmpty(), 'Each group should have identifiers');
        }
    }
    
    @isTest
    static void testGetGroupAnchorMapping() {
        List<Account> physicalLocations = [
            SELECT Id, Name, ParentId, Australian_Business_Number__c, Tax_Account_Number__c, 
                   Order_Form_Status__c, Record_Type_Developer_Name__c
            FROM Account 
            WHERE Order_Form_Anchor__c = false
        ];
        
        Test.startTest();
        Map<Id, Set<String>> result = AccountMappingService.getGroupAnchorMapping(
            physicalLocations, 
            c.ADDITIONAL_LOCATION
        );
        Test.stopTest();
        
        System.assert(!result.isEmpty(), 'Should return group mappings');
    }
    
    @isTest
    static void testGetAnchorAccountByIdentifier() {
        List<Account> groupAccounts = [
            SELECT Id FROM Account WHERE Record_Type_Developer_Name__c = :c.ACCOUNT_RT_GROUP_ACCOUNT
        ];
        
        Set<Id> groupAccountIds = new Set<Id>();
        for (Account acc : groupAccounts) {
            groupAccountIds.add(acc.Id);
        }
        
        Test.startTest();
        Account result = AccountMappingService.getAnchorAccountByIdentifier(
            'ABN123456789', 
            groupAccountIds
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should find anchor account by ABN');
        System.assertEquals('ABN123456789', result.Australian_Business_Number__c, 'Should match the ABN');
    }
    
    @isTest
    static void testBatchProcessing() {
        List<Account> physicalLocations = [
            SELECT Id, Name, ParentId, Australian_Business_Number__c, Tax_Account_Number__c, 
                   Order_Form_Status__c, Record_Type_Developer_Name__c
            FROM Account 
            WHERE Order_Form_Anchor__c = false
        ];
        
        Test.startTest();
        Map<Id, Account> result = AccountMappingService.mapAccountsBatch(
            physicalLocations, 
            c.ADDITIONAL_LOCATION, 
            2
        );
        Test.stopTest();
        
        System.assertEquals(3, result.size(), 'Batch processing should return same results');
    }
    
    @isTest
    static void testBrnPriorityOverTax() {
        // Create test data with overlapping identifiers
        Account groupAccount = new Account(
            Name = 'Test Group Account',
            Record_Type_Developer_Name__c = c.ACCOUNT_RT_GROUP_ACCOUNT,
            Order_Form_Anchor__c = true,
            Order_Form_Status__c = c.ORDER_FORM_COMPLETED,
            Australian_Business_Number__c = 'OVERLAP123',
            Tax_Account_Number__c = 'OVERLAP456'
        );
        insert groupAccount;
        
        Account anchorLocation = new Account(
            Name = 'Anchor Location',
            ParentId = groupAccount.Id,
            Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION,
            Order_Form_Anchor__c = true,
            Order_Form_Status__c = c.ORDER_FORM_COMPLETED,
            Australian_Business_Number__c = 'OVERLAP123',
            Tax_Account_Number__c = 'OVERLAP456'
        );
        insert anchorLocation;
        
        Account testLocation = new Account(
            Name = 'Test Location',
            ParentId = groupAccount.Id,
            Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION,
            Order_Form_Anchor__c = false,
            Order_Form_Status__c = c.CLONE_ORDER_FORM,
            Australian_Business_Number__c = 'OVERLAP123',
            Tax_Account_Number__c = 'DIFFERENT789'
        );
        insert testLocation;
        
        Test.startTest();
        Map<Id, Account> result = AccountMappingService.mapAccountsToAnchorAccounts(
            new List<Account>{testLocation}, 
            c.ADDITIONAL_LOCATION
        );
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should map the account');
        Account mappedAnchor = result.get(testLocation.Id);
        System.assertEquals('OVERLAP123', mappedAnchor.Australian_Business_Number__c, 'Should match by ABN priority');
    }
    
    @isTest
    static void testEdgeCases() {
        Test.startTest();
        
        // Test null input
        Map<Id, Account> nullResult = AccountMappingService.mapAccountsToAnchorAccounts(null, c.ADDITIONAL_LOCATION);
        System.assertEquals(0, nullResult.size(), 'Should handle null input gracefully');
        
        // Test empty input
        Map<Id, Account> emptyResult = AccountMappingService.mapAccountsToAnchorAccounts(
            new List<Account>(), 
            c.ADDITIONAL_LOCATION
        );
        System.assertEquals(0, emptyResult.size(), 'Should handle empty input gracefully');
        
        // Test accounts without matching criteria
        List<Account> noMatchAccounts = new List<Account>{
            new Account(
                Name = 'No Match Account', 
                Order_Form_Status__c = c.ORDER_FORM_COMPLETED, // Different status
                Record_Type_Developer_Name__c = c.ACCOUNT_RT_PHYSICAL_LOCATION
            )
        };
        Map<Id, Account> noMatchResult = AccountMappingService.mapAccountsToAnchorAccounts(
            noMatchAccounts, 
            c.ADDITIONAL_LOCATION
        );
        System.assertEquals(0, noMatchResult.size(), 'Should handle accounts without matching criteria');
        
        Test.stopTest();
    }
    
    @isTest
    static void testNaAbnHandling() {
        // Test that 'NA' ABN values are properly handled and Tax Number is used instead
        List<Account> physicalLocations = [
            SELECT Id, Name, ParentId, Australian_Business_Number__c, Tax_Account_Number__c, 
                   Order_Form_Status__c, Record_Type_Developer_Name__c
            FROM Account 
            WHERE Order_Form_Anchor__c = false 
            AND Australian_Business_Number__c = 'NA'
        ];
        
        Test.startTest();
        Map<Id, Account> result = AccountMappingService.mapAccountsToAnchorAccounts(
            physicalLocations, 
            c.ADDITIONAL_LOCATION
        );
        Test.stopTest();
        
        // Should map using Tax Number since ABN is 'NA'
        System.assertEquals(1, result.size(), 'Should map account using Tax Number when ABN is NA');
        
        Account mappedAnchor = result.values()[0];
        System.assertEquals('TAX123456', mappedAnchor.Tax_Account_Number__c, 'Should match by Tax Number');
    }
}

/**
 * Usage example class showing how to implement the optimized AccountMappingService
 */
public class OptimizedAccountMappingExample {
    
    /**
     * Example of processing physical locations for additional location opportunities
     */
    public static void processAdditionalLocationOpportunities(List<Account> physicalLocations) {
        if (physicalLocations?.isEmpty() != false) {
            System.debug('No physical locations to process');
            return;
        }
        
        // Use the optimized mapping service
        Map<Id, Account> anchorMapping = AccountMappingService.mapAccountsToAnchorAccounts(
            physicalLocations, 
            c.ADDITIONAL_LOCATION
        );
        
        System.debug('Mapped ' + anchorMapping.size() + ' physical locations to anchor accounts');
        
        // Process the mappings
        for (Id locationId : anchorMapping.keySet()) {
            Account anchorAccount = anchorMapping.get(locationId);
            System.debug('Location ' + locationId + ' mapped to anchor: ' + anchorAccount.Name);
            
            // Additional processing logic here
            // For example: create opportunities, update records, etc.
        }
    }
    
    /**
     * Example of using the group anchor mapping for complex scenarios
     */
    public static void processGroupAnchorMappings(List<Account> physicalLocations) {
        Map<Id, Set<String>> groupMappings = AccountMappingService.getGroupAnchorMapping(
            physicalLocations, 
            c.ADDITIONAL_LOCATION
        );
        
        for (Id groupId : groupMappings.keySet()) {
            Set<String> identifiers = groupMappings.get(groupId);
            System.debug('Group ' + groupId + ' has identifiers: ' + String.join(new List<String>(identifiers), ', '));
        }
    }
    
    /**
     * Example of batch processing for large datasets
     */
    public static void processBulkPhysicalLocations(List<Account> largeDataset) {
        // Use batch processing for large datasets
        Map<Id, Account> mappings = largeDataset.size() > 200 
            ? AccountMappingService.mapAccountsBatch(largeDataset, c.ADDITIONAL_LOCATION, 200)
            : AccountMappingService.mapAccountsToAnchorAccounts(largeDataset, c.ADDITIONAL_LOCATION);
        
        System.debug('Processed ' + largeDataset.size() + ' records, mapped ' + mappings.size());
    }
    
    /**
     * Example of finding specific anchor account by identifier
     */
    public static Account findAnchorByIdentifier(String identifier, Set<Id> groupIds) {
        return AccountMappingService.getAnchorAccountByIdentifier(identifier, groupIds);
    }
}