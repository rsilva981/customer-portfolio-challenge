public class CP_RoleHierarchy_Helper {
    public Map<Id, User> activeUsersMap;
    public Map<Id, UserRole> roleMap;
    public Map<Id, Set<Id>> roleToUsersMap;
    public Map<Id, Set<Id>> userToSubordinatesMap;
    public Map<Id, Set<Id>> userToManagersMap;

    public CP_RoleHierarchy_Helper() {
        loadData();
        this.userToSubordinatesMap = getUserToSubordinatesMap();
        this.userToManagersMap = getUserToManagersMap();
    }

    private void loadData() {
        List<User> users = [SELECT Id, UserRoleId FROM User WHERE IsActive = TRUE AND UserRoleId != null];
        activeUsersMap = new Map<Id, User>(users);

        Set<Id> roleIds = new Set<Id>();
        for (User u : users) roleIds.add(u.UserRoleId);

        List<UserRole> roles = [SELECT Id, ParentRoleId FROM UserRole WHERE Id IN :roleIds];
        roleMap = new Map<Id, UserRole>(roles);

        roleToUsersMap = new Map<Id, Set<Id>>();
        for (User u : users) {
            if (!roleToUsersMap.containsKey(u.UserRoleId)) {
                roleToUsersMap.put(u.UserRoleId, new Set<Id>());
            }
            roleToUsersMap.get(u.UserRoleId).add(u.Id);
        }
    }

    public Map<Id, Set<Id>> getUserToSubordinatesMap() {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        for (Id userId : activeUsersMap.keySet()) {
            Set<Id> subs = new Set<Id>();
            Set<Id> subRoles = getSubRoleIds(activeUsersMap.get(userId).UserRoleId);
            for (Id roleId : subRoles) {
                if (roleToUsersMap.containsKey(roleId)) {
                    subs.addAll(roleToUsersMap.get(roleId));
                }
            }
            result.put(userId, subs);
        }
        return result;
    }

    public Map<Id, Set<Id>> getUserToManagersMap() {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        for (Id userId : activeUsersMap.keySet()) {
            Set<Id> managers = new Set<Id>();
            Set<Id> managerRoles = getManagerRoleIds(activeUsersMap.get(userId).UserRoleId);
            for (Id roleId : managerRoles) {
                if (roleToUsersMap.containsKey(roleId)) {
                    managers.addAll(roleToUsersMap.get(roleId));
                }
            }
            result.put(userId, managers);
        }
        return result;
    }

    private Set<Id> getSubRoleIds(Id roleId) {
        Set<Id> result = new Set<Id>();
        for (Id candidateId : roleMap.keySet()) {
            Id parent = roleMap.get(candidateId).ParentRoleId;
            while (parent != null) {
                if (parent == roleId) {
                    result.add(candidateId);
                    break;
                }
                parent = roleMap.containsKey(parent) ? roleMap.get(parent).ParentRoleId : null;
            }
        }
        return result;
    }

    private Set<Id> getManagerRoleIds(Id roleId) {
        Set<Id> result = new Set<Id>();
        Id current = roleMap.containsKey(roleId) ? roleMap.get(roleId).ParentRoleId : null;
        while (current != null) {
            result.add(current);
            current = roleMap.containsKey(current) ? roleMap.get(current).ParentRoleId : null;
        }
        return result;
    }
    
    public String buildKey( Id userId, Id contactId ){
        return userId + '.' + contactId;
    }
    
    public void handleSaveResult( Database.SaveResult[] sr ){
        for( Database.SaveResult result : sr ){
            if( !result.isSuccess() ){
                System.debug( 'Error: ' + result.getErrors() ); //TODO Create log
            }
        }
    }
    
    public void handleDeleteResult( Database.DeleteResult[] dr ){
        for( Database.DeleteResult result : dr ){
            if( !result.isSuccess() ){
                System.debug( 'Error: ' + result.getErrors() ); //TODO Create log
            }
        }
    }
}