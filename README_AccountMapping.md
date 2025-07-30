# Account Mapping Service

## Overview
The `AccountMappingService` is an Apex class designed to map accounts that have BRN (Business Registration Number) or Tax Number populated to their corresponding anchor accounts.

## Key Features
- Fetches anchor accounts based on specific criteria
- Maps input accounts to anchor accounts using BRN or Tax Number
- Supports both parent-child relationships and sibling relationships
- Provides detailed mapping results with match criteria

## How It Works

### Query Criteria for Anchor Accounts
The service queries for accounts where:
1. `Anchor_Tag__c = true`
2. **AND** one of the following conditions:
   - Account ID matches the parent ID of input accounts
   - Account has the same parent as input accounts
   - Account has matching BRN or Tax Number

### Mapping Logic
1. Input accounts are matched to anchor accounts based on:
   - **Primary**: BRN number match
   - **Secondary**: Tax Number match (if BRN doesn't match)

## Usage Examples

### Basic Usage
```apex
// Get your list of accounts with BRN or Tax Number
List<Account> accountsWithBrnOrTax = [
    SELECT Id, Name, ParentId, BRN__c, Tax_Number__c
    FROM Account 
    WHERE (BRN__c != null OR Tax_Number__c != null)
    AND Anchor_Tag__c = false
];

// Get the mapping
Map<Id, Account> mapping = AccountMappingService.mapAccountsToAnchorAccounts(accountsWithBrnOrTax);

// Process results
for (Id accountId : mapping.keySet()) {
    Account anchorAccount = mapping.get(accountId);
    System.debug('Account ' + accountId + ' mapped to anchor: ' + anchorAccount.Name);
}
```

### Detailed Mapping with Match Criteria
```apex
List<AccountMappingService.AccountMappingResult> results = 
    AccountMappingService.getDetailedAccountMapping(accountsWithBrnOrTax);

for (AccountMappingService.AccountMappingResult result : results) {
    if (result.anchorAccount != null) {
        System.debug('Input: ' + result.inputAccount.Name + 
                   ' -> Anchor: ' + result.anchorAccount.Name + 
                   ' (Matched by: ' + result.matchedBy + ')');
    }
}
```

## Field Assumptions
The code assumes the following custom fields exist on the Account object:
- `BRN__c` - Business Registration Number
- `Tax_Number__c` - Tax Number  
- `Anchor_Tag__c` - Boolean field to identify anchor accounts

## Important Notes
1. **Field Names**: Update the field API names (`BRN__c`, `Tax_Number__c`, `Anchor_Tag__c`) to match your org's actual field names.
2. **Performance**: The service uses efficient querying with Set-based collections to minimize SOQL queries.
3. **Bulk Processing**: Designed to handle bulk operations efficiently.
4. **Error Handling**: Includes null checks and empty list handling.

## Test Coverage
The `AccountMappingServiceTest` class provides comprehensive test coverage including:
- Basic mapping functionality
- Detailed mapping results
- Edge cases (empty/null inputs)
- Various matching scenarios

## Customization
You can easily customize the service by:
- Modifying field names to match your org
- Adjusting the query criteria in `queryAnchorAccounts` method
- Adding additional matching logic in the mapping process