@isTest
public class AccountMappingServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Create anchor accounts efficiently
        List<Account> anchorAccounts = new List<Account>{
            new Account(
                Name = 'Anchor Account 1',
                Anchor_Tag__c = true,
                BRN__c = 'BRN123456',
                Tax_Number__c = 'TAX123456'
            ),
            new Account(
                Name = 'Anchor Account 2', 
                Anchor_Tag__c = true,
                BRN__c = 'BRN789012',
                Tax_Number__c = 'TAX789012'
            ),
            new Account(
                Name = 'Parent Anchor',
                Anchor_Tag__c = true,
                BRN__c = 'BRN999999'
            )
        };
        insert anchorAccounts;
        
        // Create child accounts with various scenarios
        List<Account> childAccounts = new List<Account>{
            new Account(
                Name = 'Child with matching BRN',
                ParentId = anchorAccounts[0].Id,
                BRN__c = 'BRN123456',
                Anchor_Tag__c = false
            ),
            new Account(
                Name = 'Child with matching Tax',
                ParentId = anchorAccounts[1].Id,
                Tax_Number__c = 'TAX789012',
                Anchor_Tag__c = false
            ),
            new Account(
                Name = 'Child with both identifiers',
                ParentId = anchorAccounts[2].Id,
                BRN__c = 'BRN999999',
                Tax_Number__c = 'TAX999999',
                Anchor_Tag__c = false
            ),
            new Account(
                Name = 'Sibling Account',
                ParentId = anchorAccounts[0].Id,
                BRN__c = 'BRN555555',
                Anchor_Tag__c = false
            )
        };
        insert childAccounts;
    }
    
    @isTest
    static void testOptimizedMapping() {
        List<Account> inputAccounts = [
            SELECT Id, Name, ParentId, BRN__c, Tax_Number__c 
            FROM Account 
            WHERE Anchor_Tag__c = false
        ];
        
        Test.startTest();
        Map<Id, Account> result = AccountMappingService.mapAccountsToAnchorAccounts(inputAccounts);
        Test.stopTest();
        
        System.assertEquals(4, result.size(), 'All accounts should be mapped');
        
        // Verify all mapped accounts are anchors
        for (Account anchor : result.values()) {
            System.assertEquals(true, anchor.Anchor_Tag__c, 'Should map to anchor accounts only');
        }
    }
    
    @isTest
    static void testSimpleIdentifierMapping() {
        List<Account> inputAccounts = [
            SELECT Id, BRN__c, Tax_Number__c 
            FROM Account 
            WHERE Anchor_Tag__c = false
        ];
        
        Test.startTest();
        Map<String, Id> result = AccountMappingService.getSimpleIdentifierMapping(inputAccounts);
        Test.stopTest();
        
        System.assert(!result.isEmpty(), 'Should return identifier mappings');
        System.assert(result.containsKey('BRN123456'), 'Should contain BRN mapping');
    }
    
    @isTest
    static void testBatchProcessing() {
        List<Account> inputAccounts = [
            SELECT Id, Name, ParentId, BRN__c, Tax_Number__c 
            FROM Account 
            WHERE Anchor_Tag__c = false
        ];
        
        Test.startTest();
        Map<Id, Account> result = AccountMappingService.mapAccountsBatch(inputAccounts, 2);
        Test.stopTest();
        
        System.assertEquals(4, result.size(), 'Batch processing should return same results');
    }
    
    @isTest
    static void testIdOnlyMapping() {
        List<Account> inputAccounts = [
            SELECT Id, Name, ParentId, BRN__c, Tax_Number__c 
            FROM Account 
            WHERE Anchor_Tag__c = false
        ];
        
        Test.startTest();
        Map<Id, Id> result = AccountMappingService.mapAccountIds(inputAccounts);
        Test.stopTest();
        
        System.assertEquals(4, result.size(), 'Should return ID mappings');
        
        // Verify IDs are valid
        for (Id anchorId : result.values()) {
            System.assertNotEquals(null, anchorId, 'Anchor ID should not be null');
        }
    }
    
    @isTest
    static void testInputValidation() {
        List<Account> validAccounts = [
            SELECT Id, BRN__c, Tax_Number__c 
            FROM Account 
            WHERE Anchor_Tag__c = false 
            LIMIT 1
        ];
        
        List<Account> invalidAccounts = new List<Account>{
            new Account(Name = 'No Identifiers')
        ];
        
        Test.startTest();
        Boolean validResult = AccountMappingService.isValidInput(validAccounts);
        Boolean invalidResult = AccountMappingService.isValidInput(invalidAccounts);
        Boolean nullResult = AccountMappingService.isValidInput(null);
        Boolean emptyResult = AccountMappingService.isValidInput(new List<Account>());
        Test.stopTest();
        
        System.assertEquals(true, validResult, 'Should validate accounts with identifiers');
        System.assertEquals(false, invalidResult, 'Should reject accounts without identifiers');
        System.assertEquals(false, nullResult, 'Should handle null input');
        System.assertEquals(false, emptyResult, 'Should handle empty input');
    }
    
    @isTest
    static void testEdgeCases() {
        Test.startTest();
        
        // Test null input
        Map<Id, Account> nullResult = AccountMappingService.mapAccountsToAnchorAccounts(null);
        System.assertEquals(0, nullResult.size(), 'Should handle null input gracefully');
        
        // Test empty input
        Map<Id, Account> emptyResult = AccountMappingService.mapAccountsToAnchorAccounts(new List<Account>());
        System.assertEquals(0, emptyResult.size(), 'Should handle empty input gracefully');
        
        // Test accounts without identifiers
        List<Account> noIdentifiers = new List<Account>{
            new Account(Name = 'Test Account', Anchor_Tag__c = false)
        };
        Map<Id, Account> noIdResult = AccountMappingService.mapAccountsToAnchorAccounts(noIdentifiers);
        System.assertEquals(0, noIdResult.size(), 'Should handle accounts without identifiers');
        
        Test.stopTest();
    }
    
    @isTest
    static void testBrnPriorityOverTax() {
        // Create test data with overlapping identifiers
        Account anchorWithBoth = new Account(
            Name = 'Anchor with Both',
            Anchor_Tag__c = true,
            BRN__c = 'OVERLAP123',
            Tax_Number__c = 'OVERLAP456'
        );
        insert anchorWithBoth;
        
        Account testAccount = new Account(
            Name = 'Test Account',
            BRN__c = 'OVERLAP123',
            Tax_Number__c = 'DIFFERENT789',
            Anchor_Tag__c = false
        );
        insert testAccount;
        
        Test.startTest();
        Map<Id, Account> result = AccountMappingService.mapAccountsToAnchorAccounts(new List<Account>{testAccount});
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should map the account');
        System.assertEquals(anchorWithBoth.Id, result.get(testAccount.Id).Id, 'Should match by BRN priority');
    }
}

/**
 * Optimized usage example with performance considerations
 */
public class OptimizedAccountMappingExample {
    
    /**
     * High-performance account mapping for large datasets
     */
    public static void processLargeDataset() {
        // Step 1: Validate input before processing
        List<Account> accounts = [
            SELECT Id, Name, ParentId, BRN__c, Tax_Number__c
            FROM Account 
            WHERE (BRN__c != null OR Tax_Number__c != null)
            AND Anchor_Tag__c = false
            LIMIT 10000
        ];
        
        if (!AccountMappingService.isValidInput(accounts)) {
            System.debug('No valid accounts to process');
            return;
        }
        
        // Step 2: Use batch processing for large datasets
        Map<Id, Account> mappings = accounts.size() > 200 
            ? AccountMappingService.mapAccountsBatch(accounts, 200)
            : AccountMappingService.mapAccountsToAnchorAccounts(accounts);
        
        // Step 3: Process results efficiently
        System.debug('Processed ' + accounts.size() + ' accounts, mapped ' + mappings.size());
        
        // For memory-efficient processing, use ID-only mapping
        if (mappings.size() > 1000) {
            Map<Id, Id> idMappings = AccountMappingService.mapAccountIds(accounts);
            // Process with IDs only to save memory
            processWithIds(idMappings);
        } else {
            // Process with full account objects for smaller datasets
            processWithFullObjects(mappings);
        }
    }
    
    /**
     * Memory-efficient processing with IDs only
     */
    private static void processWithIds(Map<Id, Id> idMappings) {
        // Batch update or other operations using only IDs
        System.debug('Processing ' + idMappings.size() + ' ID mappings efficiently');
    }
    
    /**
     * Full object processing for smaller datasets
     */
    private static void processWithFullObjects(Map<Id, Account> mappings) {
        for (Id inputId : mappings.keySet()) {
            Account anchor = mappings.get(inputId);
            System.debug('Input: ' + inputId + ' -> Anchor: ' + anchor.Name);
        }
    }
    
    /**
     * Quick identifier lookup without full mapping
     */
    public static void quickIdentifierLookup(List<Account> accounts) {
        Map<String, Id> identifierMap = AccountMappingService.getSimpleIdentifierMapping(accounts);
        
        for (Account acc : accounts) {
            Id anchorId = null;
            if (String.isNotBlank(acc.BRN__c)) {
                anchorId = identifierMap.get(acc.BRN__c);
            } else if (String.isNotBlank(acc.Tax_Number__c)) {
                anchorId = identifierMap.get(acc.Tax_Number__c);
            }
            
            if (anchorId != null) {
                System.debug('Account ' + acc.Name + ' maps to anchor: ' + anchorId);
            }
        }
    }
}