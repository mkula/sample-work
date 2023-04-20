from django.contrib import admin
from .models import Customer


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):

    @admin.display(description='First Name')
    def first_name(self, instance):
        return instance.user.first_name

    @admin.display(description='Last Name')
    def last_name(self, instance):
        return instance.user.last_name

    list_display = ('id', 'user', 'first_name', 'last_name', 'customer_id', 'modified', 'created')
