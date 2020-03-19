public class PermissionSetController {
    @AuraEnabled(cacheable=true)
    public static List<ObjectWrapper> getObjects(){
        List<ObjectWrapper> owList = new List<ObjectWrapper>();
        for(Schema.SObjectType objTyp : Schema.getGlobalDescribe().Values()){
            String name = objTyp.getDescribe().getName();
            String label = objTyp.getDescribe().getLabel();
            String prefix = objTyp.getDescribe().getKeyPrefix();
            Boolean u = objTyp.getDescribe().isUpdateable();
            Boolean a = objTyp.getDescribe().isAccessible();
            Boolean q = objTyp.getDescribe().isQueryable();
            if(u && a && q){
                if(prefix != null && (prefix.startsWith('0') || prefix.startsWith('a'))){
                    if((!name.containsignorecase('history') && !name.containsignorecase('tag')&&
                            !name.containsignorecase('share') && !name.containsignorecase('feed') && !name.containsignorecase('__mdt')
                            && !name.containsignorecase('__changeEvent') &&  !name.containsignorecase('Apex')) || 
                            name.right(3) ==  '__c'){    
                        ObjectWrapper ow = new ObjectWrapper();
                        ow.label = label;
                        ow.value = name;
                        owList.add(ow);  
                    }
                }
            }
        }
        if(!owList.isEmpty()){
            owList.sort();
        }
        return owList;
    }

    public class ObjectWrapper implements Comparable{
        @AuraEnabled public String label{get;set;}
        @AuraEnabled public String value{get;set;}

        public Integer compareTo(Object ObjToCompare) {
            return label.CompareTo(((ObjectWrapper)ObjToCompare).Label);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ObjectWrapper> getFieldsData(String objName){
        List<ObjectWrapper> owList = new List<ObjectWrapper>();
        Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map <String, Schema.SObjectField> fieldMap = schemaMap.get(objName).getDescribe().fields.getMap();
        for(Schema.SObjectField sfield : fieldMap.Values()){
            schema.describefieldresult dfield = sfield.getDescribe();
            if(dfield.isUpdateable() && dfield.isAccessible() && dfield.isPermissionable()){
                ObjectWrapper ow = new ObjectWrapper();
                ow.value = dfield.getname();
                ow.label = dfield.getLabel();
                owList.add(ow);
            }  
        }
        if(!owList.isEmpty()){
            owList.sort();
        }
        return owList;
    }

    @AuraEnabled(cacheable=true)
    public static List<ObjectWrapper> getPermissionSets(){
        List<ObjectWrapper> owList = new List<ObjectWrapper>();
        for(PermissionSet ps : [SELECT Id, Name, Label, NamespacePrefix FROM PermissionSet Where 
                               NamespacePrefix = '' AND isCustom = true]){
            if(!ps.Label.startsWith('00')){
                ObjectWrapper ow = new ObjectWrapper();
                ow.label = ps.Label;
                ow.value = ps.Name;
                owList.add(ow);
            }
        }
        if(!owList.isEmpty()){
            owList.sort();
        }
        return owList;
    }

    @AuraEnabled
    public static void updatePermissions(String objName, String perm, String selectedFields, String selectedSets, String objPerm){
        
        List<String> objPermValues = new List<String>{'PermissionsRead', 'PermissionsEdit', 'PermissionsCreate', 'PermissionsDelete', 'PermissionsViewAllRecords', 'PermissionsModifyAllRecords'};
        Set<String> permSets = new Set<String>();
        permSets.addAll(selectedSets.split(';'));

        Map<String,Boolean> mapOfObjPermissionsToValue = new Map<String,Boolean>();
        for(String str : objPermValues){
            if(objPerm.contains(str)){
                mapOfObjPermissionsToValue.put(str,true);
            }
            else{
                mapOfObjPermissionsToValue.put(str,false);
            }
        }    

        Set<String> fields = new Set<String>();
        for(String str : selectedFields.split(';')){
            if(str.contains('Billing') && !str.contains('__c')){
                fields.add(objName+'.'+'BillingAddress');
            }
            else if(str.contains('Shipping') && !str.contains('__c')){
                fields.add(objName+'.'+'ShippingAddress');
            }
            else{
                fields.add(objName+'.'+str);
            }       
        }
        Map<String, Id> mapOfPermissionSetNameToId = new Map<String, Id>();
        for(PermissionSet p : [SELECT id, name FROM PermissionSet WHERE name IN :permSets]){
            if(!mapOfPermissionSetNameToId.containsKey(p.name)){
                mapOfPermissionSetNameToId.put(p.name, p.id);
            }
        }

        Map<String, Id> mapOfCombinationToId = new Map<String, Id>();
        List<FieldPermissions> fpList = new List<FieldPermissions>();
        for(FieldPermissions fp : [SELECT Id, SobjectType, Field, PermissionsRead, PermissionsEdit, 
                                  ParentId, Parent.Name FROM FieldPermissions WHERE
                                  Parent.Name IN :permSets AND 
                                  Field IN :fields AND
                                  SObjectType =:objName]){
            String key = fp.SobjectType+'~'+fp.Parent.Name+'~'+fp.Field;
            if(!mapOfCombinationToId.containsKey(key)){
                mapOfCombinationToId.put(key, fp.Id);
            }
        }

        Map<String, Id> mapOfObjectCombinationToId = new Map<String, Id>();
        List<ObjectPermissions> opList = new List<ObjectPermissions>();
        for(ObjectPermissions op : [SELECT Id, SobjectType, PermissionsRead, PermissionsEdit, 
                                  PermissionsCreate, PermissionsDelete, 
                                  PermissionsViewAllRecords, PermissionsModifyAllRecords,
                                  ParentId, Parent.Name FROM ObjectPermissions WHERE
                                  Parent.Name IN :permSets AND 
                                  SObjectType =:objName]){
            String key = op.SobjectType+'~'+op.Parent.Name;
            if(!mapOfObjectCombinationToId.containsKey(key)){
                mapOfObjectCombinationToId.put(key, op.Id);
            }
        }

        for(String p : permSets){
            for(String f : fields){
                FieldPermissions fp = new FieldPermissions();
                String key = objName+'~'+p+'~'+f;
                if(mapOfCombinationToId.containsKey(key)){
                    fp.Id = mapOfCombinationToId.get(key);
                }
                else{
                    fp.SobjectType = objName;
                    fp.Field = f;
                    fp.ParentId = mapOfPermissionSetNameToId.get(p);
                }

                if(perm == 'Read'){
                    fp.PermissionsRead = true;
                    fp.PermissionsEdit = false;
                }
                else if(perm == 'Edit'){
                    fp.PermissionsRead = true;
                    fp.PermissionsEdit = true;
                }
                else if(perm == 'NoAccess'){
                    fp.PermissionsRead = false;
                    fp.PermissionsEdit = false;
                }
                fpList.add(fp);
            }
            ObjectPermissions op = new ObjectPermissions();
            String key = objName+'~'+p;
            if(mapOfObjectCombinationToId.containsKey(key)){
                op.Id = mapOfObjectCombinationToId.get(key);
            }
            else{
                op.SobjectType = objName;
                op.ParentId = mapOfPermissionSetNameToId.get(p);
            }

            op.PermissionsRead = false;
            op.PermissionsCreate = false;
            op.PermissionsEdit = false;
            op.PermissionsDelete = false;
            op.PermissionsViewAllRecords = false;
            op.PermissionsModifyAllRecords = false;

            if(mapOfObjPermissionsToValue.get('PermissionsRead')){
                op.PermissionsRead = true;
            }
            if(mapOfObjPermissionsToValue.get('PermissionsCreate')){
                op.PermissionsRead = true;
                op.PermissionsCreate = true;
            }
            if(mapOfObjPermissionsToValue.get('PermissionsEdit')){
                op.PermissionsRead = true;
                op.PermissionsEdit = true;
            }
            if(mapOfObjPermissionsToValue.get('PermissionsDelete')){
                op.PermissionsRead = true;
                op.PermissionsEdit = true;
                op.PermissionsDelete = true;
            }
            if(mapOfObjPermissionsToValue.get('PermissionsViewAllRecords')){
                op.PermissionsRead = true;
                op.PermissionsViewAllRecords = true;
            }
            if(mapOfObjPermissionsToValue.get('PermissionsModifyAllRecords')){
                op.PermissionsRead = true;
                op.PermissionsEdit = true;
                op.PermissionsDelete = true;
                op.PermissionsViewAllRecords = true;
                op.PermissionsModifyAllRecords = true;
            }
            opList.add(op);
        }

        if(!opList.isEmpty()){
            upsert opList;
        }

        if(!fpList.isEmpty()){
            upsert fpList;
        }
    }
}
