import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import './sticky_list.dart';
import './render.dart';

typedef InfiniteListItem ItemBuilder(BuildContext context, int index);

/// List item build should return instance on this class
///
/// It can be overriden if needed
///
/// This class build item header and content
class InfiniteListItem {
  final HeaderStateBuilder headerStateBuilder;
  final HeaderBuilder headerBuilder;
  final ContentBuilder contentBuilder;
  final MinOffsetProvider _minOffsetProvider;

  InfiniteListItem({
    @required this.contentBuilder,
    this.headerBuilder,
    this.headerStateBuilder,
    MinOffsetProvider minOffsetProvider,
  }): _minOffsetProvider = minOffsetProvider;

  /// Function, that provides min offset.
  ///
  /// If Visible content offset if less than provided value
  /// Header will be stick to bottom
  ///
  /// By default header positioned until it's offset less than content height
  MinOffsetProvider get minOffsetProvider => _minOffsetProvider ?? (state) => 0;

  bool get hasStickyHeader => headerBuilder != null || headerStateBuilder != null;

  bool get watchStickyState => headerStateBuilder != null;

  /// Header item builder
  /// Receives [BuildContext] and [StickyState]
  ///
  /// If [headerBuilder] and [headerStateBuilder] not specified, this method won't be called
  ///
  /// Second param [StickyState] will be passed if [watchStickyState] is `TRUE`
  Widget buildHeader(BuildContext context, [StickyState state]) {
    if (state == null) {
      return headerBuilder(context);
    }

    return headerStateBuilder(context, state);
  }

  /// Content item builder
  Widget buildContent(BuildContext context) => contentBuilder(context);

  /// Called during init state (see [State.initState])
  @protected
  @mustCallSuper
  void initState() {}

  /// Called whenever item is destroyed (see [State.dispose] lifecycle)
  /// If this method is override, [dispose] should called
  @protected
  @mustCallSuper
  void dispose() {}

  Widget _getHeader(BuildContext context, Stream<StickyState> stream) {
    assert(hasStickyHeader, "At least one builder should be provided");

    if (!watchStickyState) {
      return buildHeader(context);
    }

    return Positioned(
      child: StreamBuilder<StickyState>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }

          return buildHeader(context, snapshot.data);
        },
      ),
    );
  }
}


class InfiniteList extends StatefulWidget {
  final ItemBuilder builder;
  final ScrollController controller;
  final Key _centerKey = UniqueKey();

  InfiniteList({
    Key key,
    @required this.builder,
    this.controller,
  }): super(key: key);

  @override
  State<StatefulWidget> createState() => _InfiniteListState();

}

class _InfiniteListState extends State<InfiniteList> {
  StreamController<StickyState> _streamController = StreamController<StickyState>.broadcast();

  SliverList get _reverseList => SliverList(
    delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) => _getListItem(context, (index + 1) * -1),
    ),
  );

  SliverList get _forwardList => SliverList(
    delegate: SliverChildBuilderDelegate(_getListItem),
    key: widget._centerKey,
  );

  Widget _getListItem(BuildContext context, int index) => _StickyListItem(
    streamController: _streamController,
    index: index,
    listItem: widget.builder(context, index),
  );

  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: widget.controller,
    center: widget._centerKey,
    slivers: [
      _reverseList,
      _forwardList,
    ],
  );

  @override
  void dispose() {
    super.dispose();

    _streamController.close();
  }
}


class _StickyListItem extends StatefulWidget {
  final InfiniteListItem listItem;
  final int index;
  final StreamController<StickyState> streamController;

  Stream<StickyState> get _stream => streamController.stream.where((state) => state.index == index);

  _StickyListItem({
    Key key,
    this.index,
    this.listItem,
    this.streamController,
  }): super(key: key);

  @override
  State<_StickyListItem> createState() => _StickyListItemState();
}

class _StickyListItemState extends State<_StickyListItem> {

  @override
  void initState() {
    super.initState();

    widget.listItem.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.listItem.buildContent(context);

    if (!widget.listItem.hasStickyHeader) {
      return content;
    }

    return _ListItemStack(
      itemIndex: widget.index,
      streamSink: widget.streamController.sink,
      header: widget.listItem._getHeader(context, widget._stream),
      content: content,
      minOffsetProvider: widget.listItem.minOffsetProvider,
    );
  }

  @override
  void dispose() {
    super.dispose();

    widget.listItem.dispose();
  }

}


class _ListItemStack extends Stack {
  final StreamSink<StickyState> streamSink;

  final int itemIndex;
  final MinOffsetProvider minOffsetProvider;

  _ListItemStack({
    @required Widget header,
    @required Widget content,
    @required this.streamSink,
    @required this.itemIndex,
    @required this.minOffsetProvider,
    Key key,
  }): super(
    key: key,
    children: [content, header],
    alignment: AlignmentDirectional.topStart,
    overflow: Overflow.clip,
  );

  ScrollableState _getScrollableState(BuildContext context) => Scrollable.of(context);

  @override
  RenderStack createRenderObject(BuildContext context) => ListItemRenderObject(
    scrollable: _getScrollableState(context),
    alignment: alignment,
    textDirection: textDirection ?? Directionality.of(context),
    fit: fit,
    overflow: overflow,
    itemIndex: itemIndex,
    streamSink: streamSink,
    minOffsetProvider: minOffsetProvider,
  );

  @override
  void updateRenderObject(BuildContext context, ListItemRenderObject renderObject) {
    super.updateRenderObject(context, renderObject);

    renderObject
      ..scrollable = _getScrollableState(context)
      ..itemIndex = itemIndex
      ..streamSink = streamSink
      ..minOffsetProvider = minOffsetProvider;
  }
}