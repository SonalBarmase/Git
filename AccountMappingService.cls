public class AccountMappingService {
    
    // Constants for field names - easier to maintain and modify
    private static final String BRN_FIELD = 'Australian_Business_Number__c';
    private static final String TAX_FIELD = 'Tax_Account_Number__c';
    private static final String ANCHOR_FIELD = 'Order_Form_Anchor__c';
    private static final String STATUS_FIELD = 'Order_Form_Status__c';
    private static final String RECORD_TYPE_FIELD = 'Record_Type_Developer_Name__c';
    
    /**
     * Main method to map accounts with BRN/Tax Number to their anchor accounts
     * @param physicalLocations List of physical location accounts
     * @param opptyType Opportunity type for filtering
     * @return Map<Id, Account> where key is the input account Id and value is the matched anchor account
     */
    public static Map<Id, Account> mapAccountsToAnchorAccounts(List<Account> physicalLocations, String opptyType) {
        // Early return for null/empty inputs
        if (physicalLocations?.isEmpty() != false) {
            return new Map<Id, Account>();
        }
        
        // Step 1: Process physical locations and build group account data
        Map<Id, String> grpAccABNAndTaxData = new Map<Id, String>();
        List<Account> accountsWithCloneOrderForm = new List<Account>();
        
        processPhysicalLocations(physicalLocations, opptyType, grpAccABNAndTaxData, accountsWithCloneOrderForm);
        
        if (grpAccABNAndTaxData.isEmpty()) {
            return new Map<Id, Account>();
        }
        
        // Step 2: Query anchor accounts
        List<Account> anchorAccounts = queryAnchorAccountsOptimized(grpAccABNAndTaxData);
        
        // Step 3: Build anchor map based on BRN/Tax Number
        Map<String, Account> anchorMap = buildAnchorMap(anchorAccounts);
        
        // Step 4: Map input accounts to anchor accounts
        return buildAccountMapping(physicalLocations, grpAccABNAndTaxData, anchorMap);
    }
    
    /**
     * Process physical locations and extract group account data
     */
    private static void processPhysicalLocations(
        List<Account> physicalLocations, 
        String opptyType, 
        Map<Id, String> grpAccABNAndTaxData, 
        List<Account> accountsWithCloneOrderForm
    ) {
        for (Account physicalLocation : physicalLocations) {
            if (c.ADDITIONAL_LOCATION.equalsIgnoreCase(opptyType) && 
                c.CLONE_ORDER_FORM.equalsIgnoreCase(physicalLocation.Order_Form_Status__c)) {
                
                // Priority: BRN over Tax Number (excluding 'NA' values)
                if (String.isNotBlank(physicalLocation.Australian_Business_Number__c) && 
                    !physicalLocation.Australian_Business_Number__c.equalsIgnoreCase('NA')) {
                    grpAccABNAndTaxData.put(physicalLocation.ParentId, physicalLocation.Australian_Business_Number__c);
                } else if (String.isNotBlank(physicalLocation.Tax_Account_Number__c)) {
                    grpAccABNAndTaxData.put(physicalLocation.ParentId, physicalLocation.Tax_Account_Number__c);
                }
                
                // Update status and add to processing list
                physicalLocation.Order_Form_Status__c = c.ORDER_FORM_COMPLETED;
                accountsWithCloneOrderForm.add(physicalLocation);
            }
        }
    }
    
    /**
     * Optimized query for anchor accounts based on your existing pattern
     */
    private static List<Account> queryAnchorAccountsOptimized(Map<Id, String> grpAccABNAndTaxData) {
        return [
            SELECT Id, Order_Form_Anchor__c, Order_Form_Status__c, Australian_Business_Number__c, 
                   Tax_Account_Number__c, ParentId, Record_Type_Developer_Name__c
            FROM Account 
            WHERE ParentId IN :grpAccABNAndTaxData.keySet() 
            AND Order_Form_Anchor__c = true 
            AND Order_Form_Status__c = :c.ORDER_FORM_COMPLETED
            AND Record_Type_Developer_Name__c IN (:c.ACCOUNT_RT_PHYSICAL_LOCATION, :c.ACCOUNT_RT_GROUP_ACCOUNT)
            AND (Australian_Business_Number__c IN :grpAccABNAndTaxData.values() 
                 OR Tax_Account_Number__c IN :grpAccABNAndTaxData.values())
        ];
    }
    
    /**
     * Build anchor map based on BRN or Tax Number using your existing pattern
     */
    private static Map<String, Account> buildAnchorMap(List<Account> anchorAccounts) {
        Map<String, Account> anchorMap = new Map<String, Account>();
        
        for (Account anchor : anchorAccounts) {
            // Priority: BRN over Tax Number (matching your existing logic)
            String identifier = String.isNotBlank(anchor.Australian_Business_Number__c) 
                ? anchor.Australian_Business_Number__c 
                : anchor.Tax_Account_Number__c;
            
            if (String.isNotBlank(identifier)) {
                anchorMap.put(identifier, anchor);
            }
        }
        
        return anchorMap;
    }
    
    /**
     * Build the final mapping between input accounts and anchor accounts
     */
    private static Map<Id, Account> buildAccountMapping(
        List<Account> physicalLocations,
        Map<Id, String> grpAccABNAndTaxData,
        Map<String, Account> anchorMap
    ) {
        Map<Id, Account> result = new Map<Id, Account>();
        
        for (Account physicalLocation : physicalLocations) {
            if (grpAccABNAndTaxData.containsKey(physicalLocation.ParentId)) {
                String identifier = grpAccABNAndTaxData.get(physicalLocation.ParentId);
                
                if (anchorMap.containsKey(identifier)) {
                    result.put(physicalLocation.Id, anchorMap.get(identifier));
                }
            }
        }
        
        return result;
    }
    
    /**
     * Alternative method using your buildGroupAnchorMap pattern
     * Creates a map of Group Account Id to Set of identifiers (BRN/Tax)
     */
    public static Map<Id, Set<String>> buildGroupAnchorMap(
        Set<Id> groupAccountIds, 
        Set<String> setBRNNumbers, 
        Set<String> setTAXNumbers
    ) {
        Map<Id, Set<String>> grpPLAccMap = new Map<Id, Set<String>>();
        
        for (Account acc : [
            SELECT Id, Australian_Business_Number__c, Tax_Account_Number__c, ParentId, Record_Type_Developer_Name__c
            FROM Account
            WHERE (ParentId IN :groupAccountIds OR Id IN :groupAccountIds)
            AND (Australian_Business_Number__c IN :setBRNNumbers OR Tax_Account_Number__c IN :setTAXNumbers) 
            AND Order_Form_Anchor__c = true
        ]) {
            // Determine the key based on record type
            Id accountId = c.ACCOUNT_RT_PHYSICAL_LOCATION.equalsIgnoreCase(acc.Record_Type_Developer_Name__c) 
                ? acc.ParentId 
                : acc.Id;
            
            if (!grpPLAccMap.containsKey(accountId)) {
                grpPLAccMap.put(accountId, new Set<String>());
            }
            
            // Add identifier (BRN has priority)
            String identifier = String.isNotBlank(acc.Australian_Business_Number__c) 
                ? acc.Australian_Business_Number__c 
                : acc.Tax_Account_Number__c;
            
            if (String.isNotBlank(identifier)) {
                grpPLAccMap.get(accountId).add(identifier);
            }
        }
        
        return grpPLAccMap;
    }
    
    /**
     * Enhanced method that combines both approaches
     * @param physicalLocations List of physical location accounts
     * @param opptyType Opportunity type
     * @return Map<Id, Set<String>> Group account to identifiers mapping
     */
    public static Map<Id, Set<String>> getGroupAnchorMapping(List<Account> physicalLocations, String opptyType) {
        if (physicalLocations?.isEmpty() != false) {
            return new Map<Id, Set<String>>();
        }
        
        // Extract group account IDs and identifiers from physical locations
        Set<Id> groupAccountIds = new Set<Id>();
        Set<String> brnNumbers = new Set<String>();
        Set<String> taxNumbers = new Set<String>();
        
        for (Account physicalLocation : physicalLocations) {
            if (c.ADDITIONAL_LOCATION.equalsIgnoreCase(opptyType) && 
                c.CLONE_ORDER_FORM.equalsIgnoreCase(physicalLocation.Order_Form_Status__c)) {
                
                if (physicalLocation.ParentId != null) {
                    groupAccountIds.add(physicalLocation.ParentId);
                }
                
                if (String.isNotBlank(physicalLocation.Australian_Business_Number__c) && 
                    !physicalLocation.Australian_Business_Number__c.equalsIgnoreCase('NA')) {
                    brnNumbers.add(physicalLocation.Australian_Business_Number__c);
                } else if (String.isNotBlank(physicalLocation.Tax_Account_Number__c)) {
                    taxNumbers.add(physicalLocation.Tax_Account_Number__c);
                }
            }
        }
        
        // Use the buildGroupAnchorMap method
        return buildGroupAnchorMap(groupAccountIds, brnNumbers, taxNumbers);
    }
    
    /**
     * Utility method to get anchor account by identifier
     */
    public static Account getAnchorAccountByIdentifier(String identifier, Set<Id> groupAccountIds) {
        if (String.isBlank(identifier) || groupAccountIds?.isEmpty() != false) {
            return null;
        }
        
        List<Account> anchors = [
            SELECT Id, Australian_Business_Number__c, Tax_Account_Number__c, ParentId, Record_Type_Developer_Name__c
            FROM Account
            WHERE (ParentId IN :groupAccountIds OR Id IN :groupAccountIds)
            AND (Australian_Business_Number__c = :identifier OR Tax_Account_Number__c = :identifier)
            AND Order_Form_Anchor__c = true
            AND Order_Form_Status__c = :c.ORDER_FORM_COMPLETED
            LIMIT 1
        ];
        
        return anchors.isEmpty() ? null : anchors[0];
    }
    
    /**
     * Batch processing for large datasets
     */
    public static Map<Id, Account> mapAccountsBatch(List<Account> physicalLocations, String opptyType, Integer batchSize) {
        if (physicalLocations?.isEmpty() != false) {
            return new Map<Id, Account>();
        }
        
        batchSize = batchSize ?? 200;
        Map<Id, Account> finalResult = new Map<Id, Account>();
        
        for (Integer i = 0; i < physicalLocations.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, physicalLocations.size());
            List<Account> batch = new List<Account>();
            
            for (Integer j = i; j < endIndex; j++) {
                batch.add(physicalLocations[j]);
            }
            
            Map<Id, Account> batchResult = mapAccountsToAnchorAccounts(batch, opptyType);
            finalResult.putAll(batchResult);
        }
        
        return finalResult;
    }
}