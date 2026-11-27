from rest_framework import permissions

class IsMasterAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_active and request.user.is_master_admin)

class IsSuperAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_active and request.user.is_super_admin)

class IsCompanyAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        if request.user.is_super_admin:
            return True
        if request.user.role == 'COMPANY_ADMIN':
            return bool(request.user.company and request.user.company.status != 'SUSPENDED')
        return False

class IsManager(permissions.BasePermission):
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        if request.user.is_super_admin:
            return True
        if request.user.role == 'COMPANY_ADMIN':
            return bool(request.user.company and request.user.company.status != 'SUSPENDED')
        if request.user.role == 'MANAGER':
            return bool(request.user.company and request.user.company.status != 'SUSPENDED')
        return False

def _passes_active_checkin_guard(request):
    user = getattr(request, 'user', None)
    if not user or not user.is_authenticated:
        return True
    path = getattr(request, 'path', '') or ''
    if (
        '/attendance/' in path
        or '/leaves/' in path
        or '/leave-types/' in path
        or '/holidays/' in path
        or '/accounts/me/' in path
        or '/notifications/' in path
        or '/companies/' in path
    ):
        return True
    if hasattr(user, 'is_checkin_required') and user.is_checkin_required():
        return user.has_active_checkin_today()
    return True


class IsEmployee(permissions.BasePermission):
    message = "Active check-in required to access workspace features. Please check in first."

    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        if request.user.is_super_admin:
            return True
        if not (request.user.company and request.user.company.status != 'SUSPENDED'):
            return False
        return _passes_active_checkin_guard(request)

class TenantObjectPermission(permissions.BasePermission):
    """
    Enforces that the user only accesses objects belonging to their own company.
    Super Admins can access everything.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_super_admin:
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
    granular custom role / delegated permissions on request.user.
    """
    class GranularPermission(permissions.BasePermission):
        message = f"Access denied: Action requires '{perm_key}' permission."

        def has_permission(self, request, view):
            if not (request.user and request.user.is_authenticated and request.user.is_active):
                return False
            if not request.user.has_permission(perm_key):
                return False
            if not perm_key.startswith(('attendance.', 'leave.')) and perm_key != 'payroll.view_own_payslip':
                if not _passes_active_checkin_guard(request):
                    self.message = "Active check-in required to access this section. Please check in first."
                    return False
            return True

    return GranularPermission


def require_any_permission(*perm_keys: str):
    """
    Factory function returning a DRF BasePermission class that passes
    if request.user holds ANY of the provided permission keys.
    """
    class AnyGranularPermission(permissions.BasePermission):
        message = f"Access denied: Action requires one of {', '.join(perm_keys)}."

        def has_permission(self, request, view):
            if not (request.user and request.user.is_authenticated and request.user.is_active):
                return False
            if not any(request.user.has_permission(k) for k in perm_keys):
                return False
            if not any(k.startswith(('attendance.', 'leave.')) or k == 'payroll.view_own_payslip' for k in perm_keys):
                if not _passes_active_checkin_guard(request):
                    self.message = "Active check-in required to access this section. Please check in first."
                    return False
            return True

    return AnyGranularPermission

