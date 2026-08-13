import 'package:flutter_test/flutter_test.dart';

import 'package:genie_review_assistant/data/models/episode.dart';
import 'package:genie_review_assistant/data/models/job.dart';

Map<String, dynamic> _stage({
  required String code,
  required String status,
  String action = 'transition',
  String operator = 'system',
  String reason = '',
}) {
  return {
    'stage_code': code,
    'stage_status': status,
    'action': action,
    'operator': operator,
    'operator_display_name': operator,
    'reason': reason,
  };
}

Map<String, dynamic> _episode({
  dynamic status = 9,
  Map<String, dynamic>? currentStage,
  List<Map<String, dynamic>> workflow = const [],
}) {
  return {
    'id': 1,
    'status': status,
    'current_stage': currentStage,
    'stage_workflow': workflow,
  };
}

void main() {
  test('job rows use variable job IDs used by the episodes API', () {
    final job = Job.fromJson({
      'id': 900,
      'variables': [
        {'job_id': 1372352},
        {'job_id': 1372351},
      ],
    });

    expect(job.displayJobIds, [1372352, 1372351]);
    expect(job.allJobIdsForScan, [900, 1372352, 1372351]);
  });

  test('legacy reject status is treated as failed without workflow', () {
    final episode = Episode.fromJson(_episode(status: 'check_reject'));

    expect(episode.status, 2);
    expect(episode.isFailed, isTrue);
  });

  test('rejected screening episode is failed until it is reworked', () {
    final current = {'stage_code': 'screening', 'stage_status': 'pending'};
    final rejected = Episode.fromJson(_episode(
      currentStage: current,
      workflow: [
        _stage(code: 'screening', status: 'success', operator: 'alice'),
        _stage(code: 'acceptance', status: 'failed', action: 'reject'),
      ],
    ));
    final reworked = Episode.fromJson(_episode(
      currentStage: current,
      workflow: [
        _stage(code: 'screening', status: 'success', operator: 'alice'),
        _stage(code: 'acceptance', status: 'failed', action: 'reject'),
        _stage(code: 'screening', status: 'success', action: 'review'),
      ],
    ));

    expect(rejected.isFailed, isTrue);
    expect(reworked.isFailed, isFalse);
  });

  test('self review and screener filtering are excluded correctly', () {
    final current = {'stage_code': 'screening', 'stage_status': 'pending'};
    final selfReview = Episode.fromJson(_episode(
      currentStage: current,
      workflow: [
        _stage(code: 'screening', status: 'success', operator: 'alice'),
        _stage(
          code: 'acceptance',
          status: 'failed',
          action: 'reject',
          operator: 'alice',
        ),
      ],
    ));
    final byAlice = Episode.fromJson(_episode(
      currentStage: current,
      workflow: [
        _stage(code: 'screening', status: 'success', operator: 'alice'),
        _stage(code: 'acceptance', status: 'failed', action: 'reject', operator: 'bob'),
      ],
    ));

    expect(selfReview.isFailed, isFalse);
    expect(byAlice.isFailed, isTrue);
    expect(byAlice.isByScreener('ALI'), isTrue);
    expect(byAlice.isByScreener('nobody'), isFalse);
  });
}
