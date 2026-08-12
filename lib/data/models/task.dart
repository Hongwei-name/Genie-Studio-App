/// 任务模型
class Task {
  const Task({
    required this.id,
    required this.name,
    required this.notCheckCount,
  });

  final int id;
  final String name;
  final int notCheckCount;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '未命名',
      notCheckCount: (json['not_check_count'] as num?)?.toInt() ?? 0,
    );
  }
}
