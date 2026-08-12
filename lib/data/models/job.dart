import 'dart:convert';

/// Job 模型
class Job {
  const Job({
    required this.id,
    required this.variables,
    required this.unapprovedCount,
  });

  final int id;

  /// Job 变量列表（包含 job_id）
  final List<JobVariable> variables;

  /// 验收未通过数（用于失败EP预筛选）
  final int unapprovedCount;

  factory Job.fromJson(Map<String, dynamic> json) {
    final variables = <JobVariable>[];
    final rawVariables = json['variables'];

    // variables 可能是 List 或 JSON 字符串
    // 注意：dio 解析的 Map 类型可能是 _InternalLinkedHashMap，不能用 is Map<String, dynamic> 判断
    void parseVarList(List list) {
      for (final v in list) {
        if (v is Map) {
          variables.add(JobVariable.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }

    if (rawVariables is List) {
      parseVarList(rawVariables);
    } else if (rawVariables is String && rawVariables.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawVariables);
        if (decoded is List) parseVarList(decoded);
      } catch (_) {}
    }

    int unapproved = 0;
    final rrc = json['review_result_count'];
    if (rrc is Map) {
      final m = Map<String, dynamic>.from(rrc);
      unapproved = (m['unapproved_cnt'] as num?)?.toInt() ?? 0;
    }
    return Job(
      id: (json['id'] as num?)?.toInt() ?? 0,
      variables: variables,
      unapprovedCount: unapproved,
    );
  }

  /// 展示用：仅返回 job.id（一个 Job 对应一个 UI Section）
  List<int> get displayJobIds {
    return id > 0 ? <int>[id] : const <int>[];
  }

  /// 加载 EP 用：同时包含 job.id 和 variables 中的 job_id，去重
  /// 对齐原脚本 fetchJobs 第 773-781 行的双路径提取逻辑
  List<int> get allJobIdsForScan {
    final ids = <int>[];
    if (id > 0) ids.add(id);
    for (final v in variables) {
      if (v.jobId > 0 && !ids.contains(v.jobId)) {
        ids.add(v.jobId);
      }
    }
    return ids;
  }
}

class JobVariable {
  const JobVariable({required this.jobId});

  final int jobId;

  factory JobVariable.fromJson(Map<String, dynamic> json) {
    return JobVariable(
      jobId: (json['job_id'] as num?)?.toInt() ?? 0,
    );
  }
}
