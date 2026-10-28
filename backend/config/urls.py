from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # OpenAPI Documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),

    # API v1
    path('api/v1/accounts/', include('apps.accounts.urls')),
    path('api/v1/companies/', include('apps.companies.urls')),
    path('api/v1/leads/', include('apps.leads.urls')),
    path('api/v1/calls/', include('apps.calls.urls')),
    path('api/v1/callbacks/', include('apps.callbacks.urls')),
    path('api/v1/notifications/', include('apps.notifications.urls')),
    path('api/v1/analytics/', include('apps.analytics.urls')),
]
