import '../../../core/constants/enums.dart';

class ApprovalRequest {
  final String id;
  final String householdId;
  final String requestedBy;
  final String? approvedBy;
  final String requestType;
  final String title;
  final String? description;
  final String? referenceId;
  final String? referenceType;
  final ApprovalStatus status;
  final DateTime? decidedAt;
  final DateTime createdAt;
  // Populated from API joins
  final String? requesterName;
  final String? approverName;

  ApprovalRequest({
    required this.id,
    required this.householdId,
    required this.requestedBy,
    this.approvedBy,
    required this.requestType,
    required this.title,
    this.description,
    this.referenceId,
    this.referenceType,
    required this.status,
    this.decidedAt,
    required this.createdAt,
    this.requesterName,
    this.approverName,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      requestedBy: json['requested_by'] as String,
      approvedBy: json['approved_by'] as String?,
      requestType: json['request_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      status: ApprovalStatus.fromValue(json['status'] as String? ?? 'pending'),
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      requesterName: json['requester_name'] as String?,
      approverName: json['approver_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_type': requestType,
      'title': title,
      'description': description,
      'reference_id': referenceId,
      'reference_type': referenceType,
    };
  }

  ApprovalRequest copyWith({
    String? requestType,
    String? title,
    String? description,
    String? referenceId,
    String? referenceType,
    ApprovalStatus? status,
    DateTime? decidedAt,
    String? approvedBy,
    String? approverName,
  }) {
    return ApprovalRequest(
      id: id,
      householdId: householdId,
      requestedBy: requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      requestType: requestType ?? this.requestType,
      title: title ?? this.title,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      status: status ?? this.status,
      decidedAt: decidedAt ?? this.decidedAt,
      createdAt: createdAt,
      requesterName: requesterName,
      approverName: approverName ?? this.approverName,
    );
  }
}
