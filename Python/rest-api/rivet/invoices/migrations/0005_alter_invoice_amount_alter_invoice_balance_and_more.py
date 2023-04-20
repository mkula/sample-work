# Generated by Django 4.1.7 on 2023-03-27 16:14

import django.core.validators
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('invoices', '0004_alter_payment_payment_id'),
    ]

    operations = [
        migrations.AlterField(
            model_name='invoice',
            name='amount',
            field=models.DecimalField(decimal_places=2, max_digits=8, validators=[django.core.validators.MinValueValidator(0.01), django.core.validators.MaxValueValidator(100000)]),
        ),
        migrations.AlterField(
            model_name='invoice',
            name='balance',
            field=models.DecimalField(decimal_places=2, max_digits=8, validators=[django.core.validators.MinValueValidator(0.0), django.core.validators.MaxValueValidator(100000)]),
        ),
        migrations.AlterField(
            model_name='payment',
            name='amount',
            field=models.DecimalField(decimal_places=2, max_digits=8, validators=[django.core.validators.MinValueValidator(0.01), django.core.validators.MaxValueValidator(100000)]),
        ),
    ]