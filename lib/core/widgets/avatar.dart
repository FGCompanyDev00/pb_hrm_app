import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pb_hrsystem/core/utils/image_utils.dart';

List<Widget> buildMembersAvatars(
  AdvancedDayEvent<String> event,
  BuildContext context,
) {
  List<Widget> membersAvatar = [];
  List<Widget> membersList = [];
  int moreMembers = 0;
  int countMembers = 0;
  bool isEnoughCount = false;

  if (event.members != null) {
    event.members?.forEach((v) {
      countMembers += 1;
      membersList.add(avatarUserList(v['img_name'], v['member_name']));
      if (isEnoughCount) return;
      if (countMembers < 8) {
        membersAvatar.add(avatarUser(v['img_name']));
      } else {
        moreMembers = (event.members?.length ?? 0) - (countMembers - 1);
        membersAvatar.add(
          avatarMore(context, membersList, count: '+ $moreMembers'),
        );
        isEnoughCount = true;
      }
    });
  }
  return membersAvatar;
}

List<Widget> buildMembersAvatarsTimeTable(
  Events event,
  BuildContext context,
) {
  // Filter duplicate members based on employee_id
  List<dynamic> filteredMembers = [];
  final seenIds = <dynamic>{};

  if (event.members != null) {
    for (var member in event.members!) {
      if (member['employee_id'] != null &&
          seenIds.contains(member['employee_id'])) {
        continue;
      }
      seenIds.add(member['employee_id']);
      filteredMembers.add(member);
    }
  }

  List<Widget> membersAvatar = [];
  List<Widget> membersList = [];

  // Build a list of member details once
  for (var v in filteredMembers) {
    membersList.add(avatarUserList(v['img_name'], v['member_name']));
  }

  // Display up to 3 avatars
  for (int i = 0; i < filteredMembers.length && i < 3; i++) {
    membersAvatar.add(avatarUser(filteredMembers[i]['img_name']));
  }

  // Show "+ more" if there are more than 3 members
  if (filteredMembers.length > 3) {
    int remaining = filteredMembers.length - 3;
    membersAvatar.add(
      avatarMore(context, membersList, count: '+ $remaining'),
    );
  }

  return membersAvatar;
}

Widget avatarUser(String? link) {
  // Process the image URL to ensure it's valid
  final String? processedLink = ImageUtils.processImageUrl(link);
  final bool validImageUrl = ImageUtils.isValidImageUrl(processedLink);

  return Padding(
    padding: const EdgeInsets.only(right: 3),
    child: CircleAvatar(
      radius: 15,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: validImageUrl ? NetworkImage(processedLink!) : null,
      child: !validImageUrl
          ? const Icon(Icons.person, size: 15, color: Colors.grey)
          : null,
    ),
  );
}

Widget avatarUserList(String? link, name) {
  // Process the image URL to ensure it's valid
  final String? processedLink = ImageUtils.processImageUrl(link);
  final bool validImageUrl = ImageUtils.isValidImageUrl(processedLink);

  return Padding(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: validImageUrl ? NetworkImage(processedLink!) : null,
          child: !validImageUrl
              ? const Icon(Icons.person, size: 30, color: Colors.grey)
              : null,
        ),
        const SizedBox(
          width: 20,
        ),
        Text(name ?? ''),
      ],
    ),
  );
}

Widget avatarMore(BuildContext context, List<Widget> avatarList,
    {String? count}) {
  return Padding(
    padding: const EdgeInsets.only(right: 3),
    child: GestureDetector(
      onTap: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.attendant),
                content: SingleChildScrollView(
                  child: Column(
                    children: avatarList,
                  ),
                ),
              )),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          count ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    ),
  );
}
