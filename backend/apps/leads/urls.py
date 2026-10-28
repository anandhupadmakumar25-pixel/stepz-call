from django.urls import path
from apps.leads.views import (
    LeadListCreateView,
    LeadDetailView,
    BranchListCreateView,
    BranchDetailView,
    LeadCategoryListCreateView,
    LeadCategoryDetailView,
    LeadImportUploadView,
    LeadImportConfirmView,
    ImportBatchListView,
    LeadBulkAssignView,
    PermanentRegistryListView,
    CallingTaskListCreateView,
    CallingTaskDetailView
)

urlpatterns = [
    path('', LeadListCreateView.as_view(), name='lead_list_create'),
    path('<uuid:pk>/', LeadDetailView.as_view(), name='lead_detail'),
    path('branches/', BranchListCreateView.as_view(), name='branch_list_create'),
    path('branches/<uuid:pk>/', BranchDetailView.as_view(), name='branch_detail'),
    path('categories/', LeadCategoryListCreateView.as_view(), name='category_list_create'),
    path('categories/<uuid:pk>/', LeadCategoryDetailView.as_view(), name='category_detail'),
    path('tasks/', CallingTaskListCreateView.as_view(), name='calling_task_list_create'),
    path('tasks/<uuid:pk>/', CallingTaskDetailView.as_view(), name='calling_task_detail'),
    path('import/upload/', LeadImportUploadView.as_view(), name='lead_import_upload'),
    path('import/confirm/<uuid:pk>/', LeadImportConfirmView.as_view(), name='lead_import_confirm'),
    path('import/batches/', ImportBatchListView.as_view(), name='import_batch_list'),
    path('bulk-assign/', LeadBulkAssignView.as_view(), name='lead_bulk_assign'),
    path('permanent-registry/', PermanentRegistryListView.as_view(), name='permanent_registry_list'),
]
