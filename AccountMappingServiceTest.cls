@isTest
public class AccountMappingServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Create anchor accounts (parent accounts with anchor_tag = true)
        List<Account> anchorAccounts = new List<Account>();
        
        Account anchorAccount1 = new Account(
            Name = 'Anchor Account 1',
            Anchor_Tag__c = true,
            BRN__c = 'BRN123456',
            Tax_Number__c = 'TAX123456'
        );
        anchorAccounts.add(anchorAccount1);
        
        Account anchorAccount2 = new Account(
            Name = 'Anchor Account 2',
            Anchor_Tag__c = true,
            BRN__c = 'BRN789012',
            Tax_Number__c = 'TAX789012'
        );
        anchorAccounts.add(anchorAccount2);
        
        insert anchorAccounts;
        
        // Create child accounts with BRN/Tax numbers
        List<Account> childAccounts = new List<Account>();
        
        Account childAccount1 = new Account(
            Name = 'Child Account 1',
            ParentId = anchorAccount1.Id,
            BRN__c = 'BRN123456', // Same BRN as anchor
            Anchor_Tag__c = false
        );
        childAccounts.add(childAccount1);
        
        Account childAccount2 = new Account(
            Name = 'Child Account 2',
            ParentId = anchorAccount2.Id,
            Tax_Number__c = 'TAX789012', // Same Tax Number as anchor
            Anchor_Tag__c = false
        );
        childAccounts.add(childAccount2);
        
        Account childAccount3 = new Account(
            Name = 'Child Account 3',
            ParentId = anchorAccount1.Id,
            BRN__c = 'BRN999999', // Different BRN, should still match by parent relationship
            Anchor_Tag__c = false
        );
        childAccounts.add(childAccount3);
        
        insert childAccounts;
    }
    
    @isTest
    static void testMapAccountsToAnchorAccounts() {
        // Get test accounts
        List<Account> childAccounts = [SELECT Id, Name, ParentId, BRN__c, Tax_Number__c 
                                       FROM Account 
                                       WHERE Anchor_Tag__c = false];
        
        Test.startTest();
        Map<Id, Account> mappingResult = AccountMappingService.mapAccountsToAnchorAccounts(childAccounts);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(3, mappingResult.size(), 'Should have 3 mapped accounts');
        
        for (Id childAccountId : mappingResult.keySet()) {
            Account anchorAccount = mappingResult.get(childAccountId);
            System.assertNotEquals(null, anchorAccount, 'Anchor account should not be null');
            System.assertEquals(true, anchorAccount.Anchor_Tag__c, 'Matched account should have anchor tag = true');
        }
    }
    
    @isTest
    static void testGetDetailedAccountMapping() {
        // Get test accounts
        List<Account> childAccounts = [SELECT Id, Name, ParentId, BRN__c, Tax_Number__c 
                                       FROM Account 
                                       WHERE Anchor_Tag__c = false];
        
        Test.startTest();
        List<AccountMappingService.AccountMappingResult> mappingResults = 
            AccountMappingService.getDetailedAccountMapping(childAccounts);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(3, mappingResults.size(), 'Should have 3 mapping results');
        
        for (AccountMappingService.AccountMappingResult result : mappingResults) {
            System.assertNotEquals(null, result.inputAccount, 'Input account should not be null');
            System.assertNotEquals(null, result.anchorAccount, 'Anchor account should not be null');
            System.assertNotEquals('No Match', result.matchedBy, 'Should have a valid match criteria');
        }
    }
    
    @isTest
    static void testEmptyInputList() {
        Test.startTest();
        Map<Id, Account> mappingResult = AccountMappingService.mapAccountsToAnchorAccounts(new List<Account>());
        Test.stopTest();
        
        System.assertEquals(0, mappingResult.size(), 'Should return empty map for empty input');
    }
    
    @isTest
    static void testNullInputList() {
        Test.startTest();
        Map<Id, Account> mappingResult = AccountMappingService.mapAccountsToAnchorAccounts(null);
        Test.stopTest();
        
        System.assertEquals(0, mappingResult.size(), 'Should return empty map for null input');
    }
}

/**
 * Example usage class showing how to implement the AccountMappingService
 */
public class AccountMappingExample {
    
    /**
     * Example method showing how to use the service in a real scenario
     */
    public static void processAccountMapping() {
        // Step 1: Get accounts that have BRN or Tax Number populated
        List<Account> accountsWithBrnOrTax = [
            SELECT Id, Name, ParentId, BRN__c, Tax_Number__c, Anchor_Tag__c
            FROM Account 
            WHERE (BRN__c != null OR Tax_Number__c != null)
            AND Anchor_Tag__c = false
        ];
        
        if (accountsWithBrnOrTax.isEmpty()) {
            System.debug('No accounts found with BRN or Tax Number');
            return;
        }
        
        // Step 2: Get the mapping using the service
        Map<Id, Account> accountMapping = AccountMappingService.mapAccountsToAnchorAccounts(accountsWithBrnOrTax);
        
        // Step 3: Process the results
        for (Id inputAccountId : accountMapping.keySet()) {
            Account inputAccount = null;
            Account anchorAccount = accountMapping.get(inputAccountId);
            
            // Find the input account
            for (Account acc : accountsWithBrnOrTax) {
                if (acc.Id == inputAccountId) {
                    inputAccount = acc;
                    break;
                }
            }
            
            if (inputAccount != null && anchorAccount != null) {
                System.debug('Input Account: ' + inputAccount.Name + 
                           ' (BRN: ' + inputAccount.BRN__c + ', Tax: ' + inputAccount.Tax_Number__c + ')');
                System.debug('Mapped to Anchor Account: ' + anchorAccount.Name + 
                           ' (BRN: ' + anchorAccount.BRN__c + ', Tax: ' + anchorAccount.Tax_Number__c + ')');
                System.debug('---');
            }
        }
        
        // Alternative: Use detailed mapping for more information
        List<AccountMappingService.AccountMappingResult> detailedResults = 
            AccountMappingService.getDetailedAccountMapping(accountsWithBrnOrTax);
        
        System.debug('=== Detailed Mapping Results ===');
        for (AccountMappingService.AccountMappingResult result : detailedResults) {
            if (result.anchorAccount != null) {
                System.debug('Input: ' + result.inputAccount.Name + 
                           ' -> Anchor: ' + result.anchorAccount.Name + 
                           ' (Matched by: ' + result.matchedBy + ')');
            } else {
                System.debug('Input: ' + result.inputAccount.Name + ' -> No matching anchor account found');
            }
        }
    }
}