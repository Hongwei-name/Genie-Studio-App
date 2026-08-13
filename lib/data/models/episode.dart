/// EP 模型
/// 对齐原脚本 episodes API 返回结构
class Episode {
  const Episode({
    required this.id,
    required this.status,
    required this.currentStage,
    required this.stageWorkflow,
  });

  final int id;
  final int status;
  final EpisodeStage? currentStage;
  final List<StageWorkflow> stageWorkflow;

  factory Episode.fromJson(Map<String, dynamic> json) {
    EpisodeStage? currentStage;
    if (json['current_stage'] is Map) {
      currentStage = EpisodeStage.fromJson(
        Map<String, dynamic>.from(json['current_stage'] as Map),
      );
    }
    final workflow = <StageWorkflow>[];
    if (json['stage_workflow'] is List) {
      for (final s in json['stage_workflow'] as List) {
        if (s is Map) {
          workflow.add(StageWorkflow.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    return Episode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: _parseStatus(json['status']),
      currentStage: currentStage,
      stageWorkflow: workflow,
    );
  }

  /// 是否验收失败（对齐原脚本 isEpFailed）
  bool get isFailed {
    if (stageWorkflow.isEmpty) return status == 2;
    final cs = currentStage;
    if (cs == null || cs.stageCode != 'screening' || cs.stageStatus != 'pending') {
      return false;
    }

    // 从后往前找最后一次验收失败（reject）
    int lastRejectIdx = -1;
    for (var i = stageWorkflow.length - 1; i >= 0; i--) {
      final s = stageWorkflow[i];
      if (s.stageCode == 'acceptance' &&
          s.stageStatus == 'failed' &&
          s.action == 'reject') {
        lastRejectIdx = i;
        break;
      }
    }
    if (lastRejectIdx == -1) return false;

    // 检查是否已返工
    for (var i = lastRejectIdx + 1; i < stageWorkflow.length; i++) {
      final s = stageWorkflow[i];
      if (s.stageCode == 'screening' &&
          (s.stageStatus == 'success' || s.action == 'review')) {
        return false;
      }
      if (s.stageCode == 'acceptance' && s.action == 'transition') {
        return false;
      }
    }

    // 自审排除
    if (isSelfReview(lastRejectIdx)) return false;

    return true;
  }

  /// 是否自审（reject 与 screening 为同一人）
  bool isSelfReview([int? rejectIdx]) {
    if (stageWorkflow.isEmpty) return false;
    int rIdx = rejectIdx ?? -1;
    if (rIdx == -1) {
      for (var i = stageWorkflow.length - 1; i >= 0; i--) {
        final s = stageWorkflow[i];
        if (s.stageCode == 'acceptance' &&
            s.stageStatus == 'failed' &&
            s.action == 'reject') {
          rIdx = i;
          break;
        }
      }
      if (rIdx == -1) return false;
    }

    final rejectOperator = stageWorkflow[rIdx].operator.toLowerCase();
    if (rejectOperator.isEmpty) return false;

    for (var i = rIdx - 1; i >= 0; i--) {
      final s = stageWorkflow[i];
      if (s.stageCode == 'screening' && s.stageStatus == 'success') {
        if (s.operator.toLowerCase() == rejectOperator) {
          return true;
        }
      }
    }
    return false;
  }

  /// 是否由指定初筛人处理（对齐原脚本 isEpByScreener）
  bool isByScreener(String screener) {
    if (screener.isEmpty) return true;
    if (stageWorkflow.isEmpty) return true;

    int lastRejectIdx = -1;
    for (var i = stageWorkflow.length - 1; i >= 0; i--) {
      final s = stageWorkflow[i];
      if (s.stageCode == 'acceptance' &&
          s.stageStatus == 'failed' &&
          s.action == 'reject') {
        lastRejectIdx = i;
        break;
      }
    }
    if (lastRejectIdx == -1) return false;

    final screenerLower = screener.toLowerCase();
    for (var i = lastRejectIdx - 1; i >= 0; i--) {
      final s = stageWorkflow[i];
      if (s.stageCode == 'screening' && s.stageStatus == 'success') {
        final op = s.operator.toLowerCase();
        final opName = s.operatorDisplayName.toLowerCase();
        if (op == screenerLower ||
            opName == screenerLower ||
            op.contains(screenerLower) ||
            opName.contains(screenerLower)) {
          return true;
        }
      }
    }
    return false;
  }

  /// 获取失败原因（对齐原脚本 getFailReason）
  String get failReason {
    if (stageWorkflow.isEmpty) return 'status=$status';
    for (var i = stageWorkflow.length - 1; i >= 0; i--) {
      final s = stageWorkflow[i];
      if (s.stageCode == 'acceptance' &&
          s.stageStatus == 'failed' &&
          s.action == 'reject') {
        return s.reason.isNotEmpty ? s.reason : '验收失败';
      }
    }
    return '验收失败';
  }
}

class EpisodeStage {
  const EpisodeStage({
    required this.stageCode,
    required this.stageStatus,
  });

  final String stageCode;
  final String stageStatus;

  factory EpisodeStage.fromJson(Map<String, dynamic> json) {
    return EpisodeStage(
      stageCode: (json['stage_code'] as String?) ?? '',
      stageStatus: (json['stage_status'] as String?) ?? '',
    );
  }
}

int _parseStatus(dynamic value) {
  if (value is num) return value.toInt();
  switch (value) {
    case 'check_reject':
    case 'failed':
      return 2;
    case 'check_pass':
    case 'success':
      return 1;
    default:
      return int.tryParse('$value') ?? 0;
  }
}

class StageWorkflow {
  const StageWorkflow({
    required this.stageCode,
    required this.stageStatus,
    required this.action,
    required this.operator,
    required this.operatorDisplayName,
    required this.reason,
  });

  final String stageCode;
  final String stageStatus;
  final String action;
  final String operator;
  final String operatorDisplayName;
  final String reason;

  factory StageWorkflow.fromJson(Map<String, dynamic> json) {
    return StageWorkflow(
      stageCode: (json['stage_code'] as String?) ?? '',
      stageStatus: (json['stage_status'] as String?) ?? '',
      action: (json['action'] as String?) ?? '',
      operator: (json['operator'] as String?) ?? '',
      operatorDisplayName: (json['operator_display_name'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
    );
  }
}

/// 失败 EP 聚合模型（用于列表展示）
class FailedEpisode {
  const FailedEpisode({
    required this.id,
    required this.taskId,
    required this.jobId,
    required this.url,
    required this.key,
    required this.reason,
  });

  final int id;
  final int taskId;
  final int jobId;
  final String url;
  final String key;
  final String reason;

  factory FailedEpisode.from(Episode ep, int taskId, int jobId) {
    return FailedEpisode(
      id: ep.id,
      taskId: taskId,
      jobId: jobId,
      url: '', // 由 Repository 填充
      key: 'task$taskId-ep${ep.id}',
      reason: ep.failReason,
    );
  }
}
