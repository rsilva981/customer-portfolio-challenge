public class CP_RoleHierarchy_Helper {
    
    public UserRole[] userRoles;
    public Map<Id, User> activeUsersMap;
    public Map<Id, Set<Id>> roleHierarchy;
    
    public CP_RoleHierarchy_Helper(){
        this.userRoles = getUserRoles();
        this.activeUsersMap = getActiveUsersMap();
        this.roleHierarchy = getRoleHierarchy();
    }
    
    public List<UserRole> getUserRoles(){
        return [SELECT Id, ParentRoleId FROM UserRole WHERE Id IN (SELECT UserRoleId FROM User WHERE UserRoleId !='000000000000000')];
    }
     
    public Map<Id, User> getActiveUsersMap(){
        return new Map<Id, User>( [SELECT Id, UserRoleId FROM User WHERE IsActive = TRUE AND UserRoleId IN :userRoles]); 
    }

    public Map<Id, Set<Id>> getRoleHierarchy() {    // Get all roles and their parent roles
        Map<Id, Set<Id>> hierarchy = new Map<Id, Set<Id>>();

        for (UserRole role : this.userRoles) {
            if (role.ParentRoleId != null) {
                if (!hierarchy.containsKey(role.ParentRoleId)) {
                    hierarchy.put(role.ParentRoleId, new Set<Id>());
                } 
                hierarchy.get(role.ParentRoleId).add(role.Id);
            }
        }
        return hierarchy;
    }

    // Get all managers of a user recursively
    public Set<Id> getManagers(Id userId) {
        Set<Id> result = new Set<Id>();
        User user = this.activeUsersMap.get(userId);
        if (user == null || user.UserRoleId == null) return result;

        Id userRoleId = user.UserRoleId;

        for (User u : this.activeUsersMap.values()) {
            if (u.Id == userId || u.UserRoleId == null) continue;
            if (isManagerOf(u.UserRoleId, userRoleId, this.roleHierarchy)) {
                result.add(u.Id);
            }
        }
        return result;
    }

    private static Boolean isManagerOf(Id possibleManagerRole, Id userRole, Map<Id, Set<Id>> hierarchy) {
        if (possibleManagerRole == userRole) return false;
        Set<Id> children = hierarchy.get(possibleManagerRole);
        if (children == null) return false;
        if (children.contains(userRole)) return true;
        for (Id child : children) {
            if (isManagerOf(child, userRole, hierarchy)) return true;
        }
        return false;
    }
    
    public Set<Id> getSubordinates(Id managerUserId) {
        Set<Id> result = new Set<Id>();
        User manager = this.activeUsersMap.get(managerUserId);
        if (manager == null || manager.UserRoleId == null) return result;

        Set<Id> subordinateRoles = collectChildRoles(manager.UserRoleId, this.roleHierarchy);

        for (User u : this.activeUsersMap.values()) {
            if (u.Id == managerUserId || u.UserRoleId == null) continue;
            if (subordinateRoles.contains(u.UserRoleId)) {
                result.add(u.Id);
            }
        }
        return result;
    }

    // Helper to recursively collect all child roles
    private static Set<Id> collectChildRoles(Id roleId, Map<Id, Set<Id>> hierarchy) {
        Set<Id> result = new Set<Id>();
        if (!hierarchy.containsKey(roleId)) return result;

        for (Id childRole : hierarchy.get(roleId)) {
            result.add(childRole);
            result.addAll(collectChildRoles(childRole, hierarchy));
        }
        return result;
    }
    
    public String buildKey( Id userId, Id contactId ){
        return userId + '.' + contactId;
    }
    
    public Set<Id> getAllManagers(){
        Set<Id> managerRoleIds = new Set<Id>();
        for (UserRole role : this.userRoles) {
            managerRoleIds.add(role.ParentRoleId);
        }
        
        Set<Id> managerUserIds = new Set<Id>();
        for ( User u : activeUsersMap.values() ) {
            managerUserIds.add(u.Id);
        }
        
        return managerUserIds;
    }
}