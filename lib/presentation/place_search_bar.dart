import 'dart:async';

import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/place_search.dart';
import 'design.dart';
import 'localization.dart';

/// Map search field: finds a town, an address or a place, then moves the map
/// there so the trails around it can be discovered.
class PlaceSearchBar extends StatefulWidget {
  const PlaceSearchBar(this.app, {required this.openMenu, super.key});
  final AppController app;
  final VoidCallback openMenu;
  @override
  State<PlaceSearchBar> createState() => _PlaceSearchBarState();
}

class _PlaceSearchBarState extends State<PlaceSearchBar> {
  final text = TextEditingController();
  final focus = FocusNode();
  Timer? debounce;
  List<Place>? results;
  Object? error;
  bool searching = false;
  int request = 0;

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    debounce?.cancel();
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  void changed(String value) {
    debounce?.cancel();
    setState(() {});
    if (value.trim().length < 3) {
      request++;
      setState(() {
        results = null;
        error = null;
        searching = false;
      });
      return;
    }
    // Public geocoders ask for moderate use: wait until typing pauses.
    debounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(search(value)),
    );
  }

  Future<void> search(String value) async {
    debounce?.cancel();
    if (value.trim().length < 2) return;
    final id = ++request;
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final places = await widget.app.searchPlaces(value);
      if (!mounted || id != request) return;
      setState(() => results = places);
    } catch (e) {
      if (!mounted || id != request) return;
      setState(() {
        error = e;
        results = null;
      });
    } finally {
      if (mounted && id == request) setState(() => searching = false);
    }
  }

  void choose(Place place) {
    focus.unfocus();
    text.text = place.name;
    setState(() => results = null);
    widget.app.showPlace(place);
  }

  void clear() {
    debounce?.cancel();
    request++;
    text.clear();
    setState(() {
      results = null;
      error = null;
      searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showResults = focus.hasFocus && (results != null || error != null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              IconButton(
                tooltip: context.l10n.menu,
                onPressed: widget.openMenu,
                icon: const Icon(Icons.menu),
              ),
              Expanded(
                child: TextField(
                  controller: text,
                  focusNode: focus,
                  onChanged: changed,
                  onSubmitted: search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchPlaces,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (searching)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (text.text.isNotEmpty)
                IconButton(
                  tooltip: context.l10n.clearSearch,
                  onPressed: clear,
                  icon: const Icon(Icons.close),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.search, color: forest),
                ),
            ],
          ),
        ),
        if (showResults)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: error != null
                    ? ListTile(
                        leading: const Icon(Icons.cloud_off_outlined),
                        title: Text(context.message(error!)),
                      )
                    : results!.isEmpty
                    ? ListTile(title: Text(context.l10n.noPlaceFound))
                    : ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final place in results!)
                            ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(place.name),
                              subtitle: place.detail.isEmpty
                                  ? null
                                  : Text(
                                      place.detail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => choose(place),
                            ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
