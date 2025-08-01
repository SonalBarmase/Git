// ITEBIZSYS-302265
// Refactored code with improved readability and maintainability

private void processAdditionalLocationWithCloneOrderForm(PhysicalLocation physicalLocation, String opptyType) {
    if (!shouldProcessLocation(physicalLocation, opptyType)) {
        return;
    }
    
    handleABNAndTaxData(physicalLocation);
    updateOrderFormStatus(physicalLocation);
    accountsWithCloneOrderForm.add(physicalLocation);
}

private Boolean shouldProcessLocation(PhysicalLocation physicalLocation, String opptyType) {
    return c.ADDITIONAL_LOCATION.equalsIgnoreCase(opptyType) && 
           c.CLONE_ORDER_FORM.equalsIgnoreCase(physicalLocation.Order_Form_Status__c);
}

private void handleABNAndTaxData(PhysicalLocation physicalLocation) {
    String abnNumber = physicalLocation.Australian_Business_Number__c;
    String taxNumber = physicalLocation.Tax_Account_Number__c;
    
    if (isValidABN(abnNumber)) {
        GrpAccABNAndTaxData.put(physicalLocation.ParentId, abnNumber);
    } else if (String.isNotBlank(taxNumber)) {
        GrpAccABNAndTaxData.put(physicalLocation.ParentId, taxNumber);
    }
}

private Boolean isValidABN(String abnNumber) {
    return String.isNotBlank(abnNumber) && 
           !abnNumber.equalsIgnoreCase('NA');
}

private void updateOrderFormStatus(PhysicalLocation physicalLocation) {
    physicalLocation.Order_Form_Status__c = c.ORDER_FORM_COMPLETED;
}

// Original code refactored into a single method call:
// processAdditionalLocationWithCloneOrderForm(physicalLocation, opptyType);