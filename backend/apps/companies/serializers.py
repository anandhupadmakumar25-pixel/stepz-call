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
        from apps.leads.models import Lead
        return Lead.objects.filter(company=obj).count()

class CompanyCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255)
    admin_email = serializers.EmailField()
    admin_password = serializers.CharField(min_length=6)
    admin_first_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default='')
    admin_last_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default='')
    subdomain = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    contact_email = serializers.EmailField(required=False, allow_blank=True, default='')
    contact_phone = serializers.CharField(max_length=32, required=False, allow_blank=True, default='')
    default_country_code = serializers.CharField(max_length=4, required=False, default='+91')
