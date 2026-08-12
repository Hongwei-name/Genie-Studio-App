/// 任务资源模型
class Resource {
  const Resource({required this.name});

  final String name;

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(name: (json['name'] as String?) ?? '');
  }
}

/// Job 分配统计（用于首帧预览）
class Assignment {
  const Assignment({
    required this.assignmentId,
    required this.displayName,
  });

  final int assignmentId;
  final String displayName;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      assignmentId: (json['assignment_id'] as num?)?.toInt() ?? 0,
      displayName: (json['display_name'] as String?) ?? '',
    );
  }
}
