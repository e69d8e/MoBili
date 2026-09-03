import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/comment_model.dart';

void main() {
  group('CommentModel Unit Tests', () {
    test('CommentMember fromJson parses avatar, level, and fallbacks', () {
      final defaultMember = CommentMember.fromJson(null);
      expect(defaultMember.mid, equals(0));
      expect(defaultMember.uname, isEmpty);
      expect(defaultMember.avatar, isEmpty);
      expect(defaultMember.level, equals(0));

      final json = {
        'mid': '98765',
        'uname': '评论达人',
        'avatar': 'http://i1.hdslb.com/bfs/face/commenter.jpg',
        'level_info': {
          'current_level': 6,
        },
        'sign': '这是一句个性签名',
      };

      final member = CommentMember.fromJson(json);
      expect(member.mid, equals(98765));
      expect(member.uname, equals('评论达人'));
      expect(member.avatar, equals('https://i1.hdslb.com/bfs/face/commenter.jpg'));
      expect(member.level, equals(6));
      expect(member.sign, equals('这是一句个性签名'));
    });

    test('CommentItem fromJson parses message, likes, and nested replies', () {
      final json = {
        'rpid': 10001,
        'oid': 20002,
        'mid': 30003,
        'root': 0,
        'parent': 0,
        'count': 2,
        'rcount': 2,
        'like': 88,
        'ctime': 1700000000,
        'action': 1,
        'content': {
          'message': '主楼精彩评论内容',
        },
        'member': {
          'mid': 30003,
          'uname': '楼长',
          'avatar': 'https://i0.hdslb.com/avatar.jpg',
        },
        'replies': [
          {
            'rpid': 10002,
            'oid': 20002,
            'mid': 40004,
            'root': 10001,
            'parent': 10001,
            'count': 0,
            'like': 5,
            'ctime': 1700000050,
            'action': 0,
            'content': {
              'message': '赞同楼长观点！',
            },
            'member': {
              'mid': 40004,
              'uname': '热心网友',
              'avatar': 'https://i0.hdslb.com/user2.jpg',
            },
          }
        ],
      };

      final comment = CommentItem.fromJson(json);
      expect(comment.rpid, equals(10001));
      expect(comment.oid, equals(20002));
      expect(comment.message, equals('主楼精彩评论内容'));
      expect(comment.like, equals(88));
      expect(comment.isLiked, isTrue);
      expect(comment.member.uname, equals('楼长'));

      expect(comment.replies.length, equals(1));
      final sub = comment.replies.first;
      expect(sub.rpid, equals(10002));
      expect(sub.message, equals('赞同楼长观点！'));
      expect(sub.isLiked, isFalse);
      expect(sub.member.uname, equals('热心网友'));
    });

    test('CommentResult constructor sets default and explicit properties', () {
      final defaultResult = CommentResult();
      expect(defaultResult.replies, isEmpty);
      expect(defaultResult.nextCursor, equals(0));
      expect(defaultResult.nextOffset, isEmpty);
      expect(defaultResult.isEnd, isTrue);
      expect(defaultResult.totalCount, equals(0));

      final customResult = CommentResult(
        totalCount: 150,
        isEnd: false,
        nextOffset: 'offset_token_123',
        nextCursor: 2,
        replies: [
          CommentItem(
            rpid: 1,
            oid: 10,
            mid: 100,
            root: 0,
            parent: 0,
            count: 0,
            rcount: 0,
            like: 10,
            ctime: 1700000000,
            message: '测试评论',
            member: CommentMember(mid: 100, uname: 'U1', avatar: '', level: 1),
          ),
        ],
      );
      expect(customResult.totalCount, equals(150));
      expect(customResult.isEnd, isFalse);
      expect(customResult.nextOffset, equals('offset_token_123'));
      expect(customResult.nextCursor, equals(2));
      expect(customResult.replies.length, equals(1));
    });
  });
}
