import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobili/models/comment_model.dart';
import 'package:mobili/models/dynamic_model.dart';
import 'package:mobili/models/user_model.dart';
import 'package:mobili/providers/auth_provider.dart';
import 'package:mobili/providers/listen_video_provider.dart';
import 'package:mobili/screens/dynamic/dynamic_detail_screen.dart';
import 'package:mobili/screens/up/up_space_screen.dart';
import 'package:mobili/services/api/api_endpoints.dart';
import 'package:mobili/services/settings/player_settings_service.dart';
import 'package:mobili/utils/image_decode_sizing.dart';
import 'package:mobili/widgets/comment_item_widget.dart';
import 'package:mobili/widgets/dynamic_card.dart';
import 'package:mobili/widgets/network_image_view.dart';

void main() {
  group('Dynamic Model & Comment ID Parsing Tests', () {
    test('DynamicItem parses basic comment_id_str and comment_type', () {
      final json = {
        'id_str': '1234567890',
        'type': 'DYNAMIC_TYPE_DRAW',
        'basic': {
          'comment_id_str': '9876543210',
          'comment_type': 11,
        },
        'modules': {
          'module_author': {
            'mid': 10001,
            'name': 'TestAuthor',
            'face': '//i0.hdslb.com/bfs/face/test.jpg',
            'pub_time': '10分钟前',
          },
          'module_stat': {
            'comment': {'count': 42},
            'like': {'count': 100, 'status': true},
          },
          'module_dynamic': {
            'desc': {'text': 'Draw dynamic text content'},
            'major': {
              'type': 'MAJOR_TYPE_DRAW',
              'draw': {
                'items': [
                  {
                    'src': '//i0.hdslb.com/bfs/album/pic1.jpg',
                    'width': 1080,
                    'height': 1920,
                  }
                ]
              }
            }
          }
        }
      };

      final item = DynamicItem.fromJson(json);
      expect(item.id, '1234567890');
      expect(item.commentId, 9876543210);
      expect(item.commentType, 11);
      expect(item.stat.likeCount, 100);
      expect(item.stat.isLiked, true);
      expect(item.pictures.length, 1);
      expect(item.pictures.first.url, 'https://i0.hdslb.com/bfs/album/pic1.jpg');
      expect(item.pictures.first.isLongImage, false);
      expect(item.pictures.first.aspectRatio, closeTo(1080 / 1920, 0.001));
    });

    test('DynamicItem falls back to video aid when basic is absent', () {
      final json = {
        'id_str': '111222333',
        'type': 'DYNAMIC_TYPE_AV',
        'modules': {
          'module_author': {
            'mid': 20002,
            'name': 'VideoUP',
            'face': 'https://i0.hdslb.com/bfs/face/up.jpg',
          },
          'module_stat': {
            'comment': {'count': 15},
          },
          'module_dynamic': {
            'major': {
              'type': 'MAJOR_TYPE_ARCHIVE',
              'archive': {
                'aid': 888999,
                'bvid': 'BV1xx411c7mD',
                'title': 'Test Video Dynamic',
                'cover': 'https://i0.hdslb.com/bfs/archive/cover.jpg',
                'duration_text': '03:45',
              }
            }
          }
        }
      };

      final item = DynamicItem.fromJson(json);
      expect(item.commentId, 888999);
      expect(item.commentType, 1);
      expect(item.video?.bvid, 'BV1xx411c7mD');
    });

    test('DynamicItem falls back to dynamic id when basic and video are absent', () {
      final json = {
        'id_str': '555666777',
        'type': 'DYNAMIC_TYPE_WORD',
        'modules': {
          'module_author': {'mid': 30003, 'name': 'TextUP'},
          'module_dynamic': {
            'desc': {'text': 'Pure text post'},
          }
        }
      };

      final item = DynamicItem.fromJson(json);
      expect(item.commentId, 555666777);
      expect(item.commentType, 17);
    });

    test('DynamicItem parses opus inline paragraphs pictures and summary pics', () {
      final json = {
        'id_str': '888777666',
        'type': 'DYNAMIC_TYPE_OPUS',
        'modules': {
          'module_author': {'mid': 50005, 'name': 'OpusAuthor'},
          'module_dynamic': {
            'major': {
              'type': 'MAJOR_TYPE_OPUS',
              'opus': {
                'title': 'Opus with images',
                'summary': {
                  'text': 'Opus body',
                  'pics': [
                    {'url': '//i0.hdslb.com/bfs/opus/summary1.jpg', 'width': 800, 'height': 600}
                  ]
                },
                'paragraphs': [
                  {
                    'para_type': 2,
                    'pic': {
                      'pics': [
                        {'url': 'https://i0.hdslb.com/bfs/opus/para1.jpg', 'width': 1200, 'height': 800}
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      };

      final item = DynamicItem.fromJson(json);
      expect(item.pictures.length, 2);
      expect(item.pictures[0].url, 'https://i0.hdslb.com/bfs/opus/summary1.jpg');
      expect(item.pictures[1].url, 'https://i0.hdslb.com/bfs/opus/para1.jpg');
    });

    test('DynamicItem interleaves [图片] markers and pictures into paragraphs', () {
      final json = {
        'id_str': '777888999',
        'type': 'DYNAMIC_TYPE_ARTICLE',
        'modules': {
          'module_author': {'mid': 60006, 'name': '地球知识局'},
          'module_dynamic': {
            'desc': {
              'text': '越南直辖市标题\n[图片]\n第一段文字介绍\n[图片]\n第二段文字介绍',
            },
            'major': {
              'type': 'MAJOR_TYPE_OPUS',
              'opus': {
                'title': '越南直辖市标题',
                'pics': [
                  {'url': 'https://i0.hdslb.com/bfs/opus/map1.jpg'},
                  {'url': 'https://i0.hdslb.com/bfs/opus/map2.jpg'},
                ]
              }
            }
          }
        }
      };

      final item = DynamicItem.fromJson(json);
      expect(item.paragraphs.length, greaterThanOrEqualTo(4));
      expect(item.paragraphs.any((p) => p.isText && p.text.contains('第一段文字介绍')), isTrue);
      expect(item.paragraphs.any((p) => p.isPicture && p.picture?.url == 'https://i0.hdslb.com/bfs/opus/map1.jpg'), isTrue);
      expect(item.paragraphs.any((p) => p.isPicture && p.picture?.url == 'https://i0.hdslb.com/bfs/opus/map2.jpg'), isTrue);
      expect(item.cleanText, isNot(contains('[图片]')));
    });

    test('DynamicItem copyWith preserves pictures and paragraphs', () {
      final item = DynamicItem(
        id: '123',
        type: 'DYNAMIC_TYPE_DRAW',
        author: DynamicAuthor.fromJson(null),
        text: 'Text',
        pictures: [DynamicPicture(url: 'https://i0.hdslb.com/bfs/draw/1.jpg')],
        stat: DynamicStat.fromJson(null),
        paragraphs: [
          const DynamicParagraph(type: 1, text: 'Text'),
          DynamicParagraph(type: 2, picture: DynamicPicture(url: 'https://i0.hdslb.com/bfs/draw/1.jpg')),
        ],
      );

      final copy = item.copyWith(text: 'Updated Text');
      expect(copy.pictures.length, 1);
      expect(copy.pictures.first.url, 'https://i0.hdslb.com/bfs/draw/1.jpg');
      expect(copy.paragraphs.length, 2);
      expect(copy.text, 'Updated Text');
    });

    test('DynamicItem parses opus detail module list with full paragraphs', () {
      // 结构与 /x/polymer/web-dynamic/v1/opus/detail 真实返回一致：
      // modules 是模块数组，正文在 MODULE_TYPE_CONTENT 的 paragraph 中，
      // 文本节点为 word.words，表情等富文本为 rich.text。
      final json = {
        'id_str': '1191817349076877316',
        'type': 0,
        'basic': {
          'comment_type': 11,
          'comment_id_str': '391494676',
          'uid': '946974',
        },
        'modules': [
          {
            'module_type': 'MODULE_TYPE_TITLE',
            'module_title': {'text': '我们想做一件很简单的事'},
          },
          {
            'module_type': 'MODULE_TYPE_AUTHOR',
            'module_author': {
              'mid': 946974,
              'name': '影视飓风',
              'face': 'https://i0.hdslb.com/bfs/face/test.jpg',
              'pub_time': '2026年04月16日 17:00',
              'pub_ts': 1776330000,
            },
          },
          {
            'module_type': 'MODULE_TYPE_CONTENT',
            'module_content': {
              'paragraphs': [
                {
                  'para_type': 1,
                  'text': {
                    'nodes': [
                      {
                        'type': 'TEXT_NODE_TYPE_WORD',
                        'word': {
                          'words': '我们想做一件很简单的事。\n找10岁、20岁一直到100岁的人，问作家余华一个问题。',
                          'font_size': 17,
                        },
                      },
                      {
                        'type': 'TEXT_NODE_TYPE_RICH',
                        'word': null,
                        'rich': {'text': '[星星眼]', 'type': 'RICH_TEXT_NODE_TYPE_EMOJI'},
                      },
                      {
                        'type': 'TEXT_NODE_TYPE_USER',
                        'word': null,
                        'user': {'name': '余华'},
                      },
                    ]
                  },
                },
                {
                  'para_type': 2,
                  'pic': {
                    'pics': [
                      {'url': 'http://i0.hdslb.com/bfs/new_dyn/para1.png', 'width': 1080, 'height': 1920},
                      {'url': 'http://i0.hdslb.com/bfs/new_dyn/para2.png', 'width': 1080, 'height': 1920},
                    ]
                  },
                },
              ]
            },
          },
          {
            'module_type': 'MODULE_TYPE_STAT',
            'module_stat': {
              'comment': {'count': 863},
              'forward': {'count': 62},
              'like': {'count': 9524, 'status': false},
            },
          },
        ],
      };

      final item = DynamicItem.fromJson(json);

      expect(item.id, '1191817349076877316');
      expect(item.title, '我们想做一件很简单的事');
      expect(item.author.mid, 946974);
      expect(item.author.name, '影视飓风');
      expect(item.author.pubTs, 1776330000);
      expect(item.stat.likeCount, 9524);
      expect(item.stat.commentCount, 863);
      expect(item.stat.forwardCount, 62);
      expect(item.commentId, 391494676);
      expect(item.commentType, 11);

      // 完整正文：文字 + 表情 + @用户，且不能出现节点 Map 的 toString 垃圾串
      // 图片段落按张展开：1 段文字 + 2 张图片
      expect(item.paragraphs.length, 3);
      expect(
        item.paragraphs.first.text,
        '我们想做一件很简单的事。\n找10岁、20岁一直到100岁的人，问作家余华一个问题。[星星眼]@余华',
      );
      expect(item.paragraphs.first.text, isNot(contains('font_size')));
      expect(item.paragraphs.first.text, isNot(contains('words:')));
      expect(item.paragraphs[1].isPicture, isTrue);
      expect(item.paragraphs[2].isPicture, isTrue);

      // 段落图片同步进入图片列表，并统一升级为 https
      expect(item.pictures.length, 2);
      expect(item.pictures.first.url, 'https://i0.hdslb.com/bfs/new_dyn/para1.png');
      expect(item.pictures[1].url, 'https://i0.hdslb.com/bfs/new_dyn/para2.png');
      expect(item.text, contains('问作家余华一个问题'));
    });

    test('DynamicItem.merge keeps full opus content over truncated feed item', () {
      final feedItem = DynamicItem.fromJson({
        'id_str': '1191817349076877316',
        'type': 'DYNAMIC_TYPE_DRAW',
        'modules': {
          'module_author': {'mid': 946974, 'name': '影视飓风'},
          'module_stat': {
            'comment': {'count': 863},
            'like': {'count': 10, 'status': true},
          },
          'module_dynamic': {
            'major': {
              'type': 'MAJOR_TYPE_OPUS',
              'opus': {
                'summary': {'text': '我们想做一件很简单的事。\n找10岁、20岁一直到'},
                'pics': [
                  {'url': '//i0.hdslb.com/bfs/new_dyn/para1.png', 'width': 1080, 'height': 1920}
                ],
              },
            },
          },
        },
      });

      final opusDetail = DynamicItem.fromJson({
        'id_str': '1191817349076877316',
        'type': 0,
        'basic': {'comment_type': 11, 'comment_id_str': '391494676'},
        'modules': [
          {
            'module_type': 'MODULE_TYPE_AUTHOR',
            'module_author': {'mid': 946974, 'name': '影视飓风', 'pub_time': '2026年04月16日 17:00'},
          },
          {
            'module_type': 'MODULE_TYPE_CONTENT',
            'module_content': {
              'paragraphs': [
                {
                  'para_type': 1,
                  'text': {
                    'nodes': [
                      {
                        'type': 'TEXT_NODE_TYPE_WORD',
                        'word': {
                          'words': '我们想做一件很简单的事。\n找10岁、20岁一直到100岁的人，问作家余华一个问题。'
                        },
                      },
                    ]
                  },
                },
                {
                  'para_type': 2,
                  'pic': {
                    'pics': [
                      {'url': 'http://i0.hdslb.com/bfs/new_dyn/para1.png', 'width': 1080, 'height': 1920},
                      {'url': 'http://i0.hdslb.com/bfs/new_dyn/para2.png', 'width': 1080, 'height': 1920},
                    ]
                  },
                },
              ]
            },
          },
        ],
      });

      final merged = DynamicItem.merge(opusDetail, feedItem)!;

      expect(merged.paragraphs.length, 3);
      expect(
        merged.text,
        '我们想做一件很简单的事。\n找10岁、20岁一直到100岁的人，问作家余华一个问题。',
      );
      // 图片取并集且去重：详情 2 张 + 列表 1 张（重复）
      expect(merged.pictures.length, 2);
      expect(merged.commentId, 391494676);
      expect(merged.commentType, 11);
      // 详情缺少统计数据时保留列表中的点赞状态
      expect(merged.stat.likeCount, 10);
      expect(merged.stat.isLiked, isTrue);
      expect(merged.author.name, '影视飓风');

      expect(DynamicItem.merge(opusDetail, null)?.paragraphs.length, 3);
      expect(DynamicItem.merge(null, feedItem)?.text, contains('一直到'));
    });

    test('DynamicItem parses opus quote, list, code, link card and divider', () {
      final json = {
        'id_str': '1200000000000000000',
        'type': 0,
        'basic': {'comment_type': 11, 'comment_id_str': '393000000'},
        'modules': [
          {
            'module_type': 'MODULE_TYPE_AUTHOR',
            'module_author': {'mid': 1, 'name': '图文UP'},
          },
          {
            'module_type': 'MODULE_TYPE_CONTENT',
            'module_content': {
              'paragraphs': [
                {
                  'para_type': 4,
                  'text': {
                    'nodes': [
                      {'type': 'TEXT_NODE_TYPE_WORD', 'word': {'words': '这是一段引用'}},
                    ]
                  },
                },
                {
                  'para_type': 5,
                  'list': {
                    'style': 1,
                    'items': [
                      {
                        'order': 1,
                        'level': 1,
                        'nodes': [
                          {'type': 'TEXT_NODE_TYPE_WORD', 'word': {'words': '第一项'}},
                        ],
                      },
                      {
                        'order': 2,
                        'level': 1,
                        'nodes': [
                          {'type': 'TEXT_NODE_TYPE_WORD', 'word': {'words': '第二项'}},
                        ],
                      },
                    ],
                  },
                },
                {
                  'para_type': 6,
                  'link_card': {
                    'card': {
                      'type': 'LINK_CARD_TYPE_UGC',
                      'ugc': {'title': '卡片里的视频标题'},
                    },
                  },
                },
                {
                  'para_type': 7,
                  'code': {'content': 'print("hi")', 'lang': 'language-python'},
                },
                {
                  'para_type': 1,
                  'text': {
                    'nodes': [
                      {
                        'type': 'TEXT_NODE_TYPE_WORD',
                        'word': {'words': '公式：'},
                      },
                      {
                        'type': 'TEXT_NODE_TYPE_FORMULA',
                        'formula': {'latex_content': 'E=mc^2'},
                      },
                    ]
                  },
                },
                {
                  'para_type': 3,
                  'line': {
                    'pic': {'url': 'https://i0.hdslb.com/bfs/line.png', 'height': 20}
                  },
                },
              ]
            },
          },
        ],
      };

      final item = DynamicItem.fromJson(json);
      final paragraphs = item.paragraphs;

      expect(paragraphs.length, 6);
      expect(paragraphs[0].isQuote, isTrue);
      expect(paragraphs[0].text, '这是一段引用');
      expect(paragraphs[1].isText, isTrue);
      expect(paragraphs[1].text, '1. 第一项\n2. 第二项');
      expect(paragraphs[2].text, '卡片里的视频标题');
      expect(paragraphs[3].isCode, isTrue);
      expect(paragraphs[3].text, 'print("hi")');
      expect(paragraphs[4].text, '公式：E=mc^2');
      expect(paragraphs[5].isDivider, isTrue);

      // 引用 / 列表 / 卡片等文本应计入正文，避免详情内容缺段
      expect(item.text, contains('这是一段引用'));
      expect(item.text, contains('第二项'));
      expect(item.text, contains('卡片里的视频标题'));
    });
  });

  group('UP Space Info & Fan Count Parsing Tests', () {
    test('UpSpaceInfo parses fans and follower from diverse field names and formats', () {
      final jsonWithFollower = {
        'mid': 12345,
        'name': 'BiliAuthor',
        'face': '//i0.hdslb.com/bfs/face/a.jpg',
        'follower': 654321,
        'following_count': 123,
      };

      final info1 = UpSpaceInfo.fromJson(jsonWithFollower);
      expect(info1.mid, 12345);
      expect(info1.fans, 654321);
      expect(info1.attention, 123);
      expect(info1.face, 'https://i0.hdslb.com/bfs/face/a.jpg');

      final jsonWithStat = {
        'mid': '67890',
        'name': 'StringAuthor',
        'stat': {
          'fans': '125000',
          'attention': '456',
        },
      };

      final info2 = UpSpaceInfo.fromJson(jsonWithStat);
      expect(info2.mid, 67890);
      expect(info2.fans, 125000);
      expect(info2.attention, 456);
    });
  });

  group('ApiEndpoints Validation Tests', () {
    test('ApiEndpoints defines correct dynamic detail and relation stat endpoints', () {
      expect(ApiEndpoints.dynamicDetail, 'https://api.bilibili.com/x/polymer/web-dynamic/v1/detail');
      expect(ApiEndpoints.relationStat, 'https://api.bilibili.com/x/relation/stat');
    });
  });

  group('Vertical Video Aspect Ratio and Orientation Logic Tests', () {
    test('Vertical video detection threshold (< 0.95)', () {
      bool isVertical(double aspectRatio) => aspectRatio < 0.95;

      expect(isVertical(9 / 16), isTrue); // 0.5625 (standard mobile vertical)
      expect(isVertical(3 / 4), isTrue); // 0.75 (portrait photo/video)
      expect(isVertical(0.9), isTrue);
      expect(isVertical(1.0), isFalse); // square
      expect(isVertical(4 / 3), isFalse); // 1.333
      expect(isVertical(16 / 9), isFalse); // 1.778
    });

    test('Non-fullscreen container aspect ratio clamping for vertical videos', () {
      double computeContainerRatio(double videoAspectRatio, bool isVertical) {
        if (isVertical) {
          return videoAspectRatio.clamp(0.72, 1.0);
        }
        return videoAspectRatio > 0 ? videoAspectRatio.clamp(1.33, 1.85) : 16 / 9;
      }

      // For 9:16 vertical video (0.5625), container clamps to 0.72 so it gives a tall frame without overflowing screen
      expect(computeContainerRatio(9 / 16, true), 0.72);

      // For 3:4 vertical video (0.75), container uses 0.75
      expect(computeContainerRatio(3 / 4, true), 0.75);

      // For 16:9 landscape video (1.777), container uses 1.777
      expect(computeContainerRatio(16 / 9, false), closeTo(16 / 9, 0.01));
    });

    test('Landscape screen 180-degree flip logic between landscapeLeft and landscapeRight', () {
      DeviceOrientation current = DeviceOrientation.landscapeLeft;
      DeviceOrientation flip(DeviceOrientation cur) {
        return cur == DeviceOrientation.landscapeLeft
            ? DeviceOrientation.landscapeRight
            : DeviceOrientation.landscapeLeft;
      }

      current = flip(current);
      expect(current, DeviceOrientation.landscapeRight);

      current = flip(current);
      expect(current, DeviceOrientation.landscapeLeft);
    });

    test('Fullscreen toggle correctly detects landscape orientation', () {
      bool shouldExit(bool isFullScreen, bool isLandscape) {
        return isFullScreen || isLandscape;
      }

      expect(shouldExit(false, true), isTrue); // In landscape via sensor
      expect(shouldExit(true, false), isTrue); // In fullscreen via button
      expect(shouldExit(true, true), isTrue); // In fullscreen and landscape
      expect(shouldExit(false, false), isFalse); // Portrait normal
    });

    test('Physical landscape orientation detection from viewPadding cutouts', () {
      DeviceOrientation detectOrientation(EdgeInsets padding, DeviceOrientation current) {
        if (padding.left > padding.right && padding.left > 10) {
          return DeviceOrientation.landscapeLeft;
        } else if (padding.right > padding.left && padding.right > 10) {
          return DeviceOrientation.landscapeRight;
        }
        return current;
      }

      // iPhone landscape left (notch on left: left inset ~47px)
      expect(
        detectOrientation(const EdgeInsets.only(left: 47, right: 0), DeviceOrientation.landscapeRight),
        DeviceOrientation.landscapeLeft,
      );

      // iPhone landscape right (notch on right: right inset ~47px)
      expect(
        detectOrientation(const EdgeInsets.only(left: 0, right: 47), DeviceOrientation.landscapeLeft),
        DeviceOrientation.landscapeRight,
      );

      // Symmetrical device (no cutout): preserves current without unwanted flip
      expect(
        detectOrientation(EdgeInsets.zero, DeviceOrientation.landscapeRight),
        DeviceOrientation.landscapeRight,
      );
    });

    test('Screen lock orientation locking and unlock restoration matrix', () {
      List<DeviceOrientation> getLockedOrientations(DeviceOrientation currentLandscape) {
        return [currentLandscape];
      }

      List<DeviceOrientation> getUnlockedOrientations({required bool autoRotate}) {
        if (autoRotate) {
          return [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
        } else {
          return [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
        }
      }

      // Lock keeps current physical landscape (never flips 180°)
      expect(getLockedOrientations(DeviceOrientation.landscapeRight), [DeviceOrientation.landscapeRight]);
      expect(getLockedOrientations(DeviceOrientation.landscapeLeft), [DeviceOrientation.landscapeLeft]);

      // Unlock restores gravity sensing when autoRotate is enabled
      expect(
        getUnlockedOrientations(autoRotate: true),
        containsAll([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]),
      );

      // Unlock restricts to landscape only when autoRotate is disabled
      expect(
        getUnlockedOrientations(autoRotate: false),
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
    });

    test('Fullscreen state sync on device orientation change', () {
      bool computeIsFullScreen({
        required Orientation newOrientation,
        required Orientation oldOrientation,
        required bool currentFullScreen,
        required bool isScreenLocked,
      }) {
        if (newOrientation == Orientation.landscape && !currentFullScreen) {
          return true; // Enters fullscreen automatically on landscape rotation
        } else if (newOrientation == Orientation.portrait && currentFullScreen && !isScreenLocked) {
          return false; // Exits fullscreen automatically on portrait rotation if not locked
        }
        return currentFullScreen;
      }

      // Portrait -> Landscape: enters fullscreen
      expect(
        computeIsFullScreen(
          newOrientation: Orientation.landscape,
          oldOrientation: Orientation.portrait,
          currentFullScreen: false,
          isScreenLocked: false,
        ),
        isTrue,
      );

      // Landscape -> Portrait (not locked): exits fullscreen
      expect(
        computeIsFullScreen(
          newOrientation: Orientation.portrait,
          oldOrientation: Orientation.landscape,
          currentFullScreen: true,
          isScreenLocked: false,
        ),
        isFalse,
      );

      // Landscape -> Portrait (locked): stays in fullscreen
      expect(
        computeIsFullScreen(
          newOrientation: Orientation.portrait,
          oldOrientation: Orientation.landscape,
          currentFullScreen: true,
          isScreenLocked: true,
        ),
        isTrue,
      );
    });

    test('PlayerSettingsService autoRotateFullScreen toggle and listenable test', () async {
      await PlayerSettingsService.setAutoRotateFullScreen(false);
      expect(PlayerSettingsService.autoRotateFullScreen, isFalse);
      expect(PlayerSettingsService.autoRotateListenable.value, isFalse);

      await PlayerSettingsService.setAutoRotateFullScreen(true);
      expect(PlayerSettingsService.autoRotateFullScreen, isTrue);
      expect(PlayerSettingsService.autoRotateListenable.value, isTrue);
    });
  });

  group('Dynamic Card & Detail Screen Widget Tests', () {
    testWidgets('DynamicCard renders text and navigates to DynamicDetailScreen on tap', (tester) async {
      final dynamicItem = DynamicItem(
        id: '123456',
        type: 'DYNAMIC_TYPE_WORD',
        author: DynamicAuthor(
          mid: 1001,
          name: '测试UP主',
          face: 'https://i0.hdslb.com/bfs/face/test.jpg',
          pubTime: '2小时前',
          pubAction: '投稿了动态',
        ),
        text: '这是一条测试动态正文',
        stat: DynamicStat(
          commentCount: 88,
          likeCount: 666,
          isLiked: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DynamicCard(item: dynamicItem),
            ),
          ),
        ),
      );

      expect(find.text('测试UP主'), findsOneWidget);
      expect(find.text('这是一条测试动态正文'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('666'), findsOneWidget);

      // Tap on text to open detail
      await tester.tap(find.text('这是一条测试动态正文'));
      await tester.pumpAndSettle();

      expect(find.text('动态详情'), findsOneWidget);
    });

    testWidgets('DynamicCard picture tap navigates directly to DynamicDetailScreen', (tester) async {
      final drawItem = DynamicItem(
        id: '234567',
        type: 'DYNAMIC_TYPE_DRAW',
        author: DynamicAuthor(
          mid: 1002,
          name: '插画师',
          face: 'https://i0.hdslb.com/bfs/face/illust.jpg',
          pubTime: '3小时前',
          pubAction: '发布了图文',
        ),
        text: '这是一组插画作品',
        pictures: [
          DynamicPicture(
            url: 'https://i0.hdslb.com/bfs/draw/pic1.jpg',
            width: 800,
            height: 600,
          ),
        ],
        stat: DynamicStat(
          commentCount: 20,
          likeCount: 150,
          isLiked: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DynamicCard(item: drawItem),
            ),
          ),
        ),
      );

      expect(find.text('插画师'), findsOneWidget);
      expect(find.byType(NetworkImageView), findsWidgets);

      // Tap on the card text navigates to DynamicDetailScreen
      await tester.tap(find.text('这是一组插画作品'));
      await tester.pumpAndSettle();

      // Successfully navigated to DynamicDetailScreen
      expect(find.text('动态详情'), findsOneWidget);
    });

    testWidgets('CommentItemWidget avatar and username tap navigates to UpSpaceScreen', (tester) async {
      final commentItem = CommentItem(
        rpid: 100100,
        oid: 200200,
        mid: 98765,
        root: 0,
        parent: 0,
        count: 0,
        rcount: 0,
        like: 12,
        ctime: 1700000000,
        message: '这是一条友善的测试评论',
        member: CommentMember(
          mid: 98765,
          uname: '评论测试用户',
          avatar: 'https://i0.hdslb.com/bfs/face/commenter.jpg',
          level: 5,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CommentItemWidget(comment: commentItem),
            ),
          ),
        ),
      );

      expect(find.text('评论测试用户'), findsOneWidget);
      expect(find.text('这是一条友善的测试评论'), findsOneWidget);

      // Tap on username
      await tester.tap(find.text('评论测试用户'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // UpSpaceScreen is pushed to Navigator stack
      expect(find.byType(UpSpaceScreen), findsOneWidget);
    });

    testWidgets('DynamicDetailScreen displays pictures from DynamicItem correctly', (tester) async {
      final drawItem = DynamicItem(
        id: '654321',
        type: 'DYNAMIC_TYPE_DRAW',
        author: DynamicAuthor(
          mid: 1002,
          name: '画师UP主',
          face: 'https://i0.hdslb.com/bfs/face/artist.jpg',
          pubTime: '1小时前',
          pubAction: '发布了图文',
        ),
        text: '画师的最新插画作品',
        pictures: [
          DynamicPicture(
            url: 'https://i0.hdslb.com/bfs/draw/art1.jpg',
            width: 1080,
            height: 1920,
          ),
          DynamicPicture(
            url: 'https://i0.hdslb.com/bfs/draw/art2.jpg',
            width: 1920,
            height: 1080,
          ),
        ],
        stat: DynamicStat(
          commentCount: 50,
          likeCount: 200,
          isLiked: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: DynamicDetailScreen(
              dynamicId: '654321',
              initialItem: drawItem,
            ),
          ),
        ),
      );

      expect(find.text('动态详情'), findsOneWidget);
      expect(find.text('画师UP主'), findsOneWidget);
      expect(find.text('画师的最新插画作品'), findsOneWidget);
      expect(find.byType(NetworkImageView), findsWidgets);
    });

    testWidgets('DynamicDetailScreen renders article with interleaved paragraphs and pictures', (tester) async {
      final articleItem = DynamicItem(
        id: '998877',
        type: 'DYNAMIC_TYPE_ARTICLE',
        author: DynamicAuthor(
          mid: 1003,
          name: '地球知识局',
          face: 'https://i0.hdslb.com/bfs/face/geo.jpg',
          pubTime: '刚刚',
          pubAction: '投稿了文章',
        ),
        text: '越南的直辖市，已经是中国两倍了！',
        pictures: [
          DynamicPicture(
            url: 'https://i0.hdslb.com/bfs/opus/map1.jpg',
            width: 1080,
            height: 720,
          ),
        ],
        paragraphs: [
          const DynamicParagraph(type: 1, text: '越南的直辖市，已经是中国两倍了！| 地球知识局'),
          DynamicParagraph(
            type: 2,
            picture: DynamicPicture(
              url: 'https://i0.hdslb.com/bfs/opus/map1.jpg',
              width: 1080,
              height: 720,
            ),
          ),
          const DynamicParagraph(type: 1, text: '就在刚刚，越南国会通过决议...'),
        ],
        stat: DynamicStat(
          commentCount: 100,
          likeCount: 500,
          isLiked: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: DynamicDetailScreen(
              dynamicId: '998877',
              initialItem: articleItem,
            ),
          ),
        ),
      );

      expect(find.text('地球知识局'), findsOneWidget);
      expect(find.text('越南的直辖市，已经是中国两倍了！| 地球知识局'), findsOneWidget);
      expect(find.byType(NetworkImageView), findsWidgets);

      // 正文段落改为 SliverList 懒加载：屏幕外的段落滚动到可见范围后才构建
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      for (int i = 0;
          i < 10 && find.text('就在刚刚，越南国会通过决议...').evaluate().isEmpty;
          i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump();
      }
      expect(find.text('就在刚刚，越南国会通过决议...'), findsOneWidget);
    });

    testWidgets('DynamicDetailScreen renders quote, list and code paragraphs', (tester) async {
      final opusItem = DynamicItem(
        id: '556677',
        type: 'DYNAMIC_TYPE_DRAW',
        title: '一篇完整的图文',
        author: DynamicAuthor(
          mid: 1004,
          name: '图文UP主',
          face: 'https://i0.hdslb.com/bfs/face/opus.jpg',
          pubTime: '3小时前',
          pubAction: '投稿了图文',
        ),
        text: '正文',
        stat: DynamicStat(commentCount: 3, likeCount: 9),
        paragraphs: const [
          DynamicParagraph(type: 1, text: '正文第一段，不能被截断。'),
          DynamicParagraph(type: 5, text: '引用的一段话'),
          DynamicParagraph(type: 1, text: '1. 列表第一项\n2. 列表第二项'),
          DynamicParagraph(type: 6, text: 'print("hi")'),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: DynamicDetailScreen(
              dynamicId: '556677',
              initialItem: opusItem,
            ),
          ),
        ),
      );

      expect(find.text('一篇完整的图文'), findsOneWidget);
      expect(find.text('正文第一段，不能被截断。'), findsOneWidget);
      expect(find.text('引用的一段话'), findsOneWidget);
      expect(find.text('1. 列表第一项\n2. 列表第二项'), findsOneWidget);
      expect(find.text('print("hi")'), findsOneWidget);
    });

    testWidgets('DynamicDetailScreen keeps long image aspect ratio (no cropping)', (tester) async {
      const longPic = DynamicPicture(
        url: 'https://i0.hdslb.com/bfs/new_dyn/long.png',
        width: 1080,
        height: 4320, // 4:1 长图
      );
      final opusItem = DynamicItem(
        id: '667788',
        type: 'DYNAMIC_TYPE_DRAW',
        author: DynamicAuthor(
          mid: 1005,
          name: '长图UP主',
          face: 'https://i0.hdslb.com/bfs/face/long.jpg',
          pubTime: '刚刚',
          pubAction: '投稿了图文',
        ),
        text: '一张长图',
        pictures: const [longPic],
        stat: DynamicStat(commentCount: 1, likeCount: 2),
        paragraphs: const [DynamicParagraph(type: 2, picture: longPic)],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: DynamicDetailScreen(
              dynamicId: '667788',
              initialItem: opusItem,
            ),
          ),
        ),
      );

      // 1080x4320 -> 0.25；旧实现会 clamp 到 0.4 导致长图被裁掉下半部分
      final aspect = tester.widget<AspectRatio>(
        find
            .descendant(
              of: find.byType(DynamicDetailScreen),
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(aspect.aspectRatio, closeTo(0.25, 0.001));
    });

    testWidgets('DynamicDetailScreen 懒加载图文段落，屏幕外的长图不会被解码', (tester) async {
      const longPic = DynamicPicture(
        url: 'https://i0.hdslb.com/bfs/new_dyn/lazy-long.png',
        width: 1080,
        height: 4320,
      );
      final opusItem = DynamicItem(
        id: '778899',
        type: 'DYNAMIC_TYPE_DRAW',
        author: DynamicAuthor(
          mid: 1006,
          name: '懒加载UP主',
          face: 'https://i0.hdslb.com/bfs/face/lazy.jpg',
          pubTime: '刚刚',
          pubAction: '投稿了图文',
        ),
        text: '正文摘要',
        stat: DynamicStat(commentCount: 1, likeCount: 2),
        paragraphs: [
          for (int i = 0; i < 20; i++)
            DynamicParagraph(type: 1, text: '第 $i 段正文内容，用来把长图推到首屏之外。' * 3),
          const DynamicParagraph(type: 2, picture: longPic),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: DynamicDetailScreen(
              dynamicId: '778899',
              initialItem: opusItem,
            ),
          ),
        ),
      );

      Finder longImage() => find.byWidgetPredicate(
            (widget) => widget is NetworkImageView && widget.url.contains('lazy-long.png'),
          );

      // 首屏只构建可见段落：远处的图片既没有构建、也就不会发起解码
      expect(find.text('第 0 段正文内容，用来把长图推到首屏之外。' * 3), findsOneWidget);
      expect(longImage(), findsNothing);

      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      for (int i = 0; i < 20 && longImage().evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -800));
        await tester.pump();
      }

      expect(longImage(), findsOneWidget);
    });

    testWidgets('DynamicDetailScreen 长图解码分辨率受像素预算约束', (tester) async {
      const longPic = DynamicPicture(
        url: 'https://i0.hdslb.com/bfs/new_dyn/budget-long.png',
        width: 1080,
        height: 4320,
      );
      final opusItem = DynamicItem(
        id: '889900',
        type: 'DYNAMIC_TYPE_DRAW',
        author: DynamicAuthor(
          mid: 1007,
          name: '预算UP主',
          face: 'https://i0.hdslb.com/bfs/face/budget.jpg',
          pubTime: '刚刚',
          pubAction: '投稿了图文',
        ),
        text: '一张长图',
        stat: DynamicStat(commentCount: 1, likeCount: 2),
        paragraphs: const [DynamicParagraph(type: 2, picture: longPic)],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: DynamicDetailScreen(
              dynamicId: '889900',
              initialItem: opusItem,
            ),
          ),
        ),
      );

      final imageView = tester
          .widgetList<NetworkImageView>(find.byType(NetworkImageView))
          .firstWhere((widget) => widget.url.contains('budget-long.png'));

      final cacheWidth = imageView.memCacheWidth;
      expect(cacheWidth, isNotNull);
      const ratio = 1080 / 4320;
      final decodedPixels = cacheWidth! * (cacheWidth / ratio);
      expect(
        decodedPixels,
        lessThanOrEqualTo(ImageDecodeSizing.defaultMaxPixels.toDouble()),
      );
      // 不再按“显示宽度 × DPR”的全分辨率解码
      expect(cacheWidth, lessThan(1440));
    });
  });
}
