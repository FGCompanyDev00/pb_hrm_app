import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
      if (countMembers < 4) {
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

Widget avatarUser(String link) {
  return Padding(
    padding: const EdgeInsets.only(right: 3),
    child: CircleAvatar(
      radius: 15,
      backgroundImage: NetworkImage(link),
    ),
  );
}

Widget avatarUserList(String link, name) {
  return Padding(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage(link),
        ),
        const SizedBox(
          width: 20,
        ),
        Text(name),
      ],
    ),
  );
}

Widget avatarMore(BuildContext context, List<Widget> avatarList, {String? count}) {
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
