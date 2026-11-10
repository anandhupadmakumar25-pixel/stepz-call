from rest_framework import permissions

class IsSuperAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_active and request.user.role == 'SUPER_ADMIN')

class IsCompanyAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        if request.user.role == 'SUPER_ADMIN':
            return True
        if request.user.role == 'COMPANY_ADMIN':
            return bool(request.user.company and request.user.company.status != 'SUSPENDED')
        return False

class IsManager(permissions.BasePermission):
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        if request.user.role == 'SUPER_ADMIN':
            return True
        if request.user.role == 'COMPANY_ADMIN':
            return bool(request.user.company and request.user.company.status != 'SUSPENDED')
        if request.user.role == 'MANAGER':
            return bool(request.user.company and request.user.company.status != 'SUSPENDED')
        return False

class IsEmployee(permissions.BasePermission):
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        if request.user.role == 'SUPER_ADMIN':
            return True
        return bool(request.user.company and request.user.company.status != 'SUSPENDED')

class TenantObjectPermission(permissions.BasePermission):
    """
    Enforces that the user only accesses objects belonging to their own company.
    Super Admins can access everything.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.role == 'SUPER_ADMIN':
            return True
        
        obj_company = getattr(obj, 'company', None)
        if obj_company is None and hasattr(obj, 'user'):
            obj_company = getattr(obj.user, 'company', None)
            
        if obj_company is None:
            return True
            
        return request.user.company_id == obj_company.id

def require_permission(perm_key: str):
    """
    Factory function returning a DRF BasePermission class that checks
    granular custom role permissions on request.user.
    """
    class GranularPermission(permissions.BasePermission):
        message = f"Access denied: Action requires '{perm_key}' permission."

        def has_permission(self, request, view):
            if not (request.user and request.user.is_authenticated and request.user.is_active):
                return False
            return request.user.has_permission(perm_key)

    return GranularPermission

