enum LoadProgressStatus {
  assigned('assigned', 'Assigned'),
  accepted('accepted', 'Accepted'),
  arrivedAtPickup('arrived_at_pickup', 'Arrived at pickup'),
  inTransit('in_transit', 'Picked up / in transit'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled');

  const LoadProgressStatus(this.value, this.label);

  final String value;
  final String label;

  static LoadProgressStatus fromValue(String? value) {
    return LoadProgressStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => LoadProgressStatus.assigned,
    );
  }

  bool canTransitionTo(LoadProgressStatus next) {
    return switch (this) {
      LoadProgressStatus.assigned => next == LoadProgressStatus.accepted,
      LoadProgressStatus.accepted => next == LoadProgressStatus.arrivedAtPickup,
      LoadProgressStatus.arrivedAtPickup =>
        next == LoadProgressStatus.inTransit,
      LoadProgressStatus.inTransit => next == LoadProgressStatus.delivered,
      LoadProgressStatus.delivered || LoadProgressStatus.cancelled => false,
    };
  }

  LoadProgressStatus? get next {
    return switch (this) {
      LoadProgressStatus.assigned => LoadProgressStatus.accepted,
      LoadProgressStatus.accepted => LoadProgressStatus.arrivedAtPickup,
      LoadProgressStatus.arrivedAtPickup => LoadProgressStatus.inTransit,
      LoadProgressStatus.inTransit => LoadProgressStatus.delivered,
      LoadProgressStatus.delivered || LoadProgressStatus.cancelled => null,
    };
  }

  String? get nextActionLabel {
    return switch (this) {
      LoadProgressStatus.assigned => 'Accept assignment',
      LoadProgressStatus.accepted => 'I arrived at pickup',
      LoadProgressStatus.arrivedAtPickup => 'Picked up / start trip',
      LoadProgressStatus.inTransit => 'Complete delivery',
      LoadProgressStatus.delivered || LoadProgressStatus.cancelled => null,
    };
  }
}
