public class AccountMappingService {
    
    // Constants for field names - easier to maintain and modify
    private static final String BRN_FIELD = 'BRN__c';
    private static final String TAX_FIELD = 'Tax_Number__c';
    private static final String ANCHOR_FIELD = 'Anchor_Tag__c';
    
    /**
     * Optimized method to map accounts with BRN/Tax Number to their anchor accounts
     * @param accountsWithBrnOrTax List of accounts that have BRN or Tax Number populated
     * @return Map<Id, Account> where key is the input account Id and value is the matched anchor account
     */
    public static Map<Id, Account> mapAccountsToAnchorAccounts(List<Account> accountsWithBrnOrTax) {
        // Early return for null/empty inputs
        if (accountsWithBrnOrTax?.isEmpty() != false) {
            return new Map<Id, Account>();
        }
        
        // Single pass collection of all required data
        Set<Id> parentIds = new Set<Id>();
        Set<String> identifiers = new Set<String>(); // Combined BRN and Tax numbers
        Map<String, List<Account>> brnToAccounts = new Map<String, List<Account>>();
        Map<String, List<Account>> taxToAccounts = new Map<String, List<Account>>();
        
        for (Account acc : accountsWithBrnOrTax) {
            // Collect parent IDs
            if (acc.ParentId != null) {
                parentIds.add(acc.ParentId);
            }
            
            // Process BRN
            if (String.isNotBlank(acc.BRN__c)) {
                identifiers.add(acc.BRN__c);
                if (!brnToAccounts.containsKey(acc.BRN__c)) {
                    brnToAccounts.put(acc.BRN__c, new List<Account>());
                }
                brnToAccounts.get(acc.BRN__c).add(acc);
            }
            
            // Process Tax Number
            if (String.isNotBlank(acc.Tax_Number__c)) {
                identifiers.add(acc.Tax_Number__c);
                if (!taxToAccounts.containsKey(acc.Tax_Number__c)) {
                    taxToAccounts.put(acc.Tax_Number__c, new List<Account>());
                }
                taxToAccounts.get(acc.Tax_Number__c).add(acc);
            }
        }
        
        // Single optimized query for all anchor accounts
        List<Account> anchorAccounts = queryAnchorAccountsOptimized(parentIds, identifiers);
        
        // Build result map efficiently
        return buildAccountMapping(anchorAccounts, brnToAccounts, taxToAccounts);
    }
    
    /**
     * Optimized query method with single SOQL call
     */
    private static List<Account> queryAnchorAccountsOptimized(Set<Id> parentIds, Set<String> identifiers) {
        // Build dynamic query conditions
        List<String> conditions = new List<String>();
        
        if (!parentIds.isEmpty()) {
            conditions.add('(Id IN :parentIds OR ParentId IN :parentIds)');
        }
        
        if (!identifiers.isEmpty()) {
            conditions.add('(' + BRN_FIELD + ' IN :identifiers OR ' + TAX_FIELD + ' IN :identifiers)');
        }
        
        // Return empty list if no conditions
        if (conditions.isEmpty()) {
            return new List<Account>();
        }
        
        String query = String.format(
            'SELECT Id, Name, ParentId, {0}, {1}, {2} FROM Account WHERE {2} = true AND ({3})',
            new List<String>{
                BRN_FIELD, TAX_FIELD, ANCHOR_FIELD, String.join(conditions, ' OR ')
            }
        );
        
        return Database.query(query);
    }
    
    /**
     * Efficiently builds the mapping between input accounts and anchor accounts
     */
    private static Map<Id, Account> buildAccountMapping(
        List<Account> anchorAccounts,
        Map<String, List<Account>> brnToAccounts,
        Map<String, List<Account>> taxToAccounts
    ) {
        Map<Id, Account> result = new Map<Id, Account>();
        
        // Process each anchor account once
        for (Account anchor : anchorAccounts) {
            // Match by BRN (higher priority)
            if (String.isNotBlank(anchor.BRN__c) && brnToAccounts.containsKey(anchor.BRN__c)) {
                for (Account inputAccount : brnToAccounts.get(anchor.BRN__c)) {
                    result.put(inputAccount.Id, anchor);
                }
            }
            
            // Match by Tax Number (only if not already matched by BRN)
            if (String.isNotBlank(anchor.Tax_Number__c) && taxToAccounts.containsKey(anchor.Tax_Number__c)) {
                for (Account inputAccount : taxToAccounts.get(anchor.Tax_Number__c)) {
                    if (!result.containsKey(inputAccount.Id)) { // Prevent BRN override
                        result.put(inputAccount.Id, anchor);
                    }
                }
            }
        }
        
        return result;
    }
    
    /**
     * Lightweight method for simple mapping without detailed results
     * @param accountsWithBrnOrTax List of accounts to map
     * @return Map<String, Id> where key is BRN/Tax and value is anchor account Id
     */
    public static Map<String, Id> getSimpleIdentifierMapping(List<Account> accountsWithBrnOrTax) {
        if (accountsWithBrnOrTax?.isEmpty() != false) {
            return new Map<String, Id>();
        }
        
        Set<String> identifiers = new Set<String>();
        for (Account acc : accountsWithBrnOrTax) {
            if (String.isNotBlank(acc.BRN__c)) identifiers.add(acc.BRN__c);
            if (String.isNotBlank(acc.Tax_Number__c)) identifiers.add(acc.Tax_Number__c);
        }
        
        Map<String, Id> result = new Map<String, Id>();
        if (!identifiers.isEmpty()) {
            String query = String.format(
                'SELECT Id, {0}, {1} FROM Account WHERE {2} = true AND ({0} IN :identifiers OR {1} IN :identifiers)',
                new List<String>{BRN_FIELD, TAX_FIELD, ANCHOR_FIELD}
            );
            
            for (Account anchor : Database.query(query)) {
                if (String.isNotBlank(anchor.BRN__c)) result.put(anchor.BRN__c, anchor.Id);
                if (String.isNotBlank(anchor.Tax_Number__c)) result.put(anchor.Tax_Number__c, anchor.Id);
            }
        }
        
        return result;
    }
    
    /**
     * Batch processing method for large datasets
     * @param accountsWithBrnOrTax Large list of accounts to process
     * @param batchSize Number of accounts to process per batch (default: 200)
     * @return Map<Id, Account> Complete mapping result
     */
    public static Map<Id, Account> mapAccountsBatch(List<Account> accountsWithBrnOrTax, Integer batchSize) {
        if (accountsWithBrnOrTax?.isEmpty() != false) {
            return new Map<Id, Account>();
        }
        
        batchSize = batchSize ?? 200; // Default batch size
        Map<Id, Account> finalResult = new Map<Id, Account>();
        
        for (Integer i = 0; i < accountsWithBrnOrTax.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, accountsWithBrnOrTax.size());
            List<Account> batch = new List<Account>();
            
            for (Integer j = i; j < endIndex; j++) {
                batch.add(accountsWithBrnOrTax[j]);
            }
            
            Map<Id, Account> batchResult = mapAccountsToAnchorAccounts(batch);
            finalResult.putAll(batchResult);
        }
        
        return finalResult;
    }
    
    /**
     * Memory-efficient method that returns only account IDs
     * @param accountsWithBrnOrTax List of accounts to map
     * @return Map<Id, Id> where key is input account Id and value is anchor account Id
     */
    public static Map<Id, Id> mapAccountIds(List<Account> accountsWithBrnOrTax) {
        Map<Id, Account> fullMapping = mapAccountsToAnchorAccounts(accountsWithBrnOrTax);
        Map<Id, Id> idMapping = new Map<Id, Id>();
        
        for (Id inputId : fullMapping.keySet()) {
            idMapping.put(inputId, fullMapping.get(inputId).Id);
        }
        
        return idMapping;
    }
    
    /**
     * Utility method to validate input data
     * @param accounts List of accounts to validate
     * @return Boolean indicating if the data is valid for processing
     */
    public static Boolean isValidInput(List<Account> accounts) {
        if (accounts?.isEmpty() != false) {
            return false;
        }
        
        for (Account acc : accounts) {
            if (String.isNotBlank(acc.BRN__c) || String.isNotBlank(acc.Tax_Number__c)) {
                return true; // At least one account has required data
            }
        }
        
        return false;
    }
}