from rest_framework import serializers
from apps.companies.models import Company

class CompanySerializer(serializers.ModelSerializer):
    user_count = serializers.SerializerMethodField()
    lead_count = serializers.SerializerMethodField()

    class Meta:
        model = Company
        fields = [
            'id', 'name', 'subdomain', 'contact_email', 'contact_phone',
            'status', 'default_country_code', 'default_country_iso',
            'settings', 'user_count', 'lead_count', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_user_count(self, obj):
        return obj.users.count()

    def get_lead_count(self, obj):
        return obj.leads.count()

class CompanyCreateSerializer(serializers.ModelSerializer):
    admin_email = serializers.EmailField(write_only=True)
    admin_password = serializers.CharField(write_only=True)
    admin_first_name = serializers.CharField(write_only=True)
    admin_last_name = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Company
        fields = [
            'name', 'subdomain', 'contact_email', 'contact_phone',
            'status', 'default_country_code', 'default_country_iso',
            'admin_email', 'admin_password', 'admin_first_name', 'admin_last_name'
        ]
