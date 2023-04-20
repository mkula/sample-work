from rest_framework import serializers

from django.contrib.auth.models import User
from .models import Invoice, Payment


class InvoiceSerializer(serializers.ModelSerializer):
    customer_full_name = serializers.CharField(source='customer.full_name', read_only=True)
    customer_id = serializers.UUIDField(source='customer.customer_id', read_only=True)

    class Meta:
        model = Invoice
        fields = [
            'customer_full_name',
            'customer_id',
            'invoice_id',
            'amount',
            'balance',
            'created',
            'modified'
        ]

    def validate(self, data):
        amount = data.get('amount')
        balance = data.get('balance')

        if amount and balance and balance > amount:
                raise serializers.ValidationError('Invoice.balance cannot be greater than Invoice.amount.')

        return data


class PaymentSerializer(serializers.ModelSerializer):
    customer_full_name = serializers.CharField(source='customer.full_name')
    customer_id = serializers.UUIDField(source='customer.customer_id')
    invoice_id = serializers.UUIDField(source='invoice.invoice_id')

    class Meta:
        model = Payment
        fields = [
            'customer_full_name',
            'customer_id',
            'invoice_id',
            'payment_id',
            'amount',
            'created',
            'modified'
        ]
        read_only_fields = [
            'customer_full_name',
            'customer_id',
            'invoice_id',
        ]


class PaymentPostSerializer(serializers.ModelSerializer):
    invoice = serializers.PrimaryKeyRelatedField(queryset=Invoice.objects.filter())

    class Meta:
        model = Payment
        fields = [
            'invoice',
            'amount',
        ]

    def __init__(self, *args, **kwargs):
        """Populate self.user = User from the Request instance passed in kwargs['context']."""
        self.user: User = None

        context: dict = kwargs.get('context')
        if context:
            request: 'Request' = context.get('request')
            if hasattr(request, 'user') and isinstance(request.user, User):
                self.user = request.user
            if hasattr(request, '_user') and isinstance(request._user, User):
                self.user = request._user

        super().__init__(*args, **kwargs)

    def get_fields(self) -> list:
        """Limit queryset results to Customer/User making the request."""
        fields: list = super().get_fields()

        if self.user:
            fields['invoice'].queryset = Invoice.objects.filter(customer__user=self.user)

        return fields
