public class AccountMappingService {
    
    /**
     * Maps accounts with BRN/Tax Number to their corresponding anchor accounts
     * @param accountsWithBrnOrTax List of accounts that have BRN or Tax Number populated
     * @return Map<Id, Account> where key is the input account Id and value is the matched anchor account
     */
    public static Map<Id, Account> mapAccountsToAnchorAccounts(List<Account> accountsWithBrnOrTax) {
        Map<Id, Account> accountMappingResult = new Map<Id, Account>();
        
        if (accountsWithBrnOrTax == null || accountsWithBrnOrTax.isEmpty()) {
            return accountMappingResult;
        }
        
        // Collect all parent IDs and BRN/Tax Numbers for querying
        Set<Id> parentIds = new Set<Id>();
        Set<String> brnNumbers = new Set<String>();
        Set<String> taxNumbers = new Set<String>();
        
        for (Account acc : accountsWithBrnOrTax) {
            if (acc.ParentId != null) {
                parentIds.add(acc.ParentId);
            }
            if (String.isNotBlank(acc.BRN__c)) { // Assuming BRN is a custom field
                brnNumbers.add(acc.BRN__c);
            }
            if (String.isNotBlank(acc.Tax_Number__c)) { // Assuming Tax Number is a custom field
                taxNumbers.add(acc.Tax_Number__c);
            }
        }
        
        // Query for anchor accounts that match the criteria
        List<Account> anchorAccounts = queryAnchorAccounts(parentIds, brnNumbers, taxNumbers);
        
        // Create maps for efficient lookup
        Map<String, Account> brnToAnchorAccount = new Map<String, Account>();
        Map<String, Account> taxToAnchorAccount = new Map<String, Account>();
        
        for (Account anchorAcc : anchorAccounts) {
            if (String.isNotBlank(anchorAcc.BRN__c)) {
                brnToAnchorAccount.put(anchorAcc.BRN__c, anchorAcc);
            }
            if (String.isNotBlank(anchorAcc.Tax_Number__c)) {
                taxToAnchorAccount.put(anchorAcc.Tax_Number__c, anchorAcc);
            }
        }
        
        // Map each input account to its corresponding anchor account
        for (Account inputAccount : accountsWithBrnOrTax) {
            Account matchedAnchorAccount = null;
            
            // First try to match by BRN
            if (String.isNotBlank(inputAccount.BRN__c) && brnToAnchorAccount.containsKey(inputAccount.BRN__c)) {
                matchedAnchorAccount = brnToAnchorAccount.get(inputAccount.BRN__c);
            }
            // If no BRN match, try Tax Number
            else if (String.isNotBlank(inputAccount.Tax_Number__c) && taxToAnchorAccount.containsKey(inputAccount.Tax_Number__c)) {
                matchedAnchorAccount = taxToAnchorAccount.get(inputAccount.Tax_Number__c);
            }
            
            if (matchedAnchorAccount != null) {
                accountMappingResult.put(inputAccount.Id, matchedAnchorAccount);
            }
        }
        
        return accountMappingResult;
    }
    
    /**
     * Queries for anchor accounts based on the criteria
     * @param parentIds Set of parent account IDs
     * @param brnNumbers Set of BRN numbers to match
     * @param taxNumbers Set of Tax numbers to match
     * @return List<Account> of anchor accounts that match the criteria
     */
    private static List<Account> queryAnchorAccounts(Set<Id> parentIds, Set<String> brnNumbers, Set<String> taxNumbers) {
        String query = 'SELECT Id, Name, ParentId, BRN__c, Tax_Number__c, Anchor_Tag__c ' +
                       'FROM Account ' +
                       'WHERE Anchor_Tag__c = true AND (';
        
        List<String> conditions = new List<String>();
        
        // Add condition for accounts that are parents of input accounts
        if (!parentIds.isEmpty()) {
            conditions.add('Id IN :parentIds');
        }
        
        // Add condition for accounts that have the same parent as input accounts
        if (!parentIds.isEmpty()) {
            conditions.add('ParentId IN :parentIds');
        }
        
        // Add condition for matching BRN or Tax Number
        if (!brnNumbers.isEmpty() || !taxNumbers.isEmpty()) {
            List<String> brnTaxConditions = new List<String>();
            if (!brnNumbers.isEmpty()) {
                brnTaxConditions.add('BRN__c IN :brnNumbers');
            }
            if (!taxNumbers.isEmpty()) {
                brnTaxConditions.add('Tax_Number__c IN :taxNumbers');
            }
            conditions.add('(' + String.join(brnTaxConditions, ' OR ') + ')');
        }
        
        query += String.join(conditions, ' OR ') + ')';
        
        return Database.query(query);
    }
    
    /**
     * Alternative method that returns a more detailed mapping result
     * @param accountsWithBrnOrTax List of accounts that have BRN or Tax Number populated
     * @return List<AccountMappingResult> containing detailed mapping information
     */
    public static List<AccountMappingResult> getDetailedAccountMapping(List<Account> accountsWithBrnOrTax) {
        List<AccountMappingResult> results = new List<AccountMappingResult>();
        Map<Id, Account> mappings = mapAccountsToAnchorAccounts(accountsWithBrnOrTax);
        
        for (Account inputAccount : accountsWithBrnOrTax) {
            AccountMappingResult result = new AccountMappingResult();
            result.inputAccount = inputAccount;
            result.anchorAccount = mappings.get(inputAccount.Id);
            result.matchedBy = determineMatchCriteria(inputAccount, result.anchorAccount);
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * Determines how the accounts were matched
     */
    private static String determineMatchCriteria(Account inputAccount, Account anchorAccount) {
        if (anchorAccount == null) {
            return 'No Match';
        }
        
        if (String.isNotBlank(inputAccount.BRN__c) && inputAccount.BRN__c == anchorAccount.BRN__c) {
            return 'BRN';
        } else if (String.isNotBlank(inputAccount.Tax_Number__c) && inputAccount.Tax_Number__c == anchorAccount.Tax_Number__c) {
            return 'Tax Number';
        }
        
        return 'Unknown';
    }
    
    /**
     * Wrapper class for detailed mapping results
     */
    public class AccountMappingResult {
        public Account inputAccount { get; set; }
        public Account anchorAccount { get; set; }
        public String matchedBy { get; set; }
    }
}