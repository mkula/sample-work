import uuid

from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator, MaxValueValidator

from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from customers.models import Customer
from django.db import models


class Invoice(models.Model):
    # customer = Customer.objects.get(customer_id=uuid.UUID('6056d964-ba2e-4e71-a583-3d56d0f74e89'))
    # customer.invoices
    customer = models.ForeignKey(
        Customer,
        on_delete=models.CASCADE,
        related_name='invoices'
    )
    invoice_id = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True
    )
    amount = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        validators=[MinValueValidator(0.01), MaxValueValidator(100000)]
    )
    balance = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        validators=[MinValueValidator(0.00), MaxValueValidator(100000)]
    )
    created = models.DateTimeField(auto_now_add=True)
    modified = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created']
        indexes = [models.Index(fields=['-created'])]

    def __str__(self):
        return str(self.invoice_id)


class Payment(models.Model):
    # customer = Customer.objects.get(customer_id=uuid.UUID('6056d964-ba2e-4e71-a583-3d56d0f74e89'))
    # customer.payments
    customer = models.ForeignKey(
        Customer,
        on_delete=models.CASCADE,
        related_name='payments'
    )
    # invoice = Invoice.objects.get(invoice_id=uuid.UUID('5315c8ae-6799-4104-bb3b-0fbcc5fd7544'))
    # invoice.payments
    invoice = models.ForeignKey(
        Invoice,
        on_delete=models.CASCADE,
        related_name='payments'
    )
    payment_id = models.UUIDField(
        # We want to apply the same payment_id to payments that were applied to multiple invoices
        # in the same API POST request
        unique=False,
    )
    amount = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        validators=[MinValueValidator(0.01), MaxValueValidator(100000)]
    )
    created = models.DateTimeField(auto_now_add=True)
    modified = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created']
        indexes = [models.Index(fields=['-created'])]

    def __str__(self):
        return f'{self.payment_id} -- {self.invoice})'


@receiver(pre_save, sender=Invoice)
def check_invoice_amount_balance(sender, instance, **kwargs):
    """Invoice pre_save signal handler that makes sure that Invoice.amount >= Invoice.balance."""
    if instance.balance > instance.amount:
        raise ValidationError('Invoice.balance cannot be greater than Invoice.amount')


@receiver(pre_save, sender=Payment)
def update_invoice_balance(sender, instance, **kwargs):
    """Payment pre_save signal handler that updates the invoice balance."""
    if instance.amount > instance.invoice.balance:
        raise ValidationError('Payment.amount cannot be greater than remaining Invoice.balance')

    instance.invoice.balance = instance.invoice.balance - instance.amount
    instance.invoice.save()


