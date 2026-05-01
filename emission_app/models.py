"""
Models for the emission tracking application.
"""

from django.db import models


class ActivityType(models.Model):
    activity_name = models.CharField(max_length=100, unique=True)
    emission_factor = models.FloatField(help_text="kg CO2 per unit")
    unit = models.CharField(max_length=20)

    def __str__(self):
        return f"{self.activity_name} ({self.emission_factor} kg CO2/{self.unit})"


class EmissionRecord(models.Model):
    activity = models.ForeignKey(ActivityType, on_delete=models.CASCADE)
    quantity = models.FloatField()
    emission_amount = models.FloatField(help_text="kg CO2")
    date = models.DateField()
    description = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        self.emission_amount = self.quantity * self.activity.emission_factor
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.activity.activity_name} - {self.emission_amount:.2f} kg CO2 on {self.date}"

    class Meta:
        ordering = ['-date', '-created_at']


class EmissionGoal(models.Model):
    PERIOD_CHOICES = [
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
    ]

    title = models.CharField(max_length=100)
    target_emission = models.FloatField(help_text="Target kg CO2 per period")
    period = models.CharField(max_length=10, choices=PERIOD_CHOICES, default='monthly')
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} ({self.target_emission} kg CO2/{self.period})"

    class Meta:
        ordering = ['-created_at']