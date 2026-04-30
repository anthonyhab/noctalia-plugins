import QtQuick
import qs.Commons

Item {
  id: root

  property int currentIndex: 0
  property int previousIndex: 0
  property bool initialized: false
  property bool animating: false
  property real transitionGap: Math.round(Style.marginXS)
  property real transitionTime: Math.max(100, Style.animationFast)
  property list<Item> contentItems: []

  default property alias content: container.data

  clip: true

  Item {
    id: container
    anchors.fill: parent
  }

  function setIndexWithoutAnimation(idx) {
    fromXAnim.stop();
    toXAnim.stop();
    animating = false;
    previousIndex = idx;
    for (let i = 0; i < contentItems.length; i++) {
      const item = contentItems[i];
      if (!item)
        continue;

      item.x = i === idx ? 0 : root.width;
      item.visible = i === idx;
    }
  }

  function initializeItems() {
    contentItems = [];
    const count = container.children.length;
    for (let i = 0; i < count; i++) {
      const child = container.children[i];
      if (!child)
        continue;

      contentItems.push(child);
      child.width = Qt.binding(() => root.width);
      child.height = Qt.binding(() => root.height);
      child.x = i === currentIndex ? 0 : root.width;
      child.visible = i === currentIndex;
    }
    previousIndex = currentIndex;
    initialized = true;
  }

  function animateTransition(fromIdx, toIdx) {
    fromXAnim.stop();
    toXAnim.stop();

    const fromItem = contentItems[fromIdx];
    const toItem = contentItems[toIdx];
    if (!fromItem || !toItem)
      return;

    const slideLeft = toIdx > fromIdx;
    const offset = root.width + transitionGap;

    for (let i = 0; i < contentItems.length; i++) {
      const item = contentItems[i];
      if (!item || i === fromIdx || i === toIdx)
        continue;

      item.visible = false;
      item.x = root.width;
    }

    fromItem.visible = true;
    fromItem.x = 0;

    toItem.visible = true;
    toItem.x = slideLeft ? offset : -offset;

    animating = true;

    fromXAnim.target = fromItem;
    fromXAnim.to = slideLeft ? -offset : offset;
    toXAnim.target = toItem;
    toXAnim.to = 0;

    fromXAnim.start();
    toXAnim.start();
  }

  Component.onCompleted: initializeItems()

  onCurrentIndexChanged: {
    if (!initialized || contentItems.length === 0)
      return;
    if (previousIndex === currentIndex)
      return;

    animateTransition(previousIndex, currentIndex);
    previousIndex = currentIndex;
  }

  onWidthChanged: {
    if (!initialized)
      return;

    for (let i = 0; i < contentItems.length; i++) {
      const item = contentItems[i];
      if (!item)
        continue;

      if (i !== currentIndex && !animating)
        item.x = root.width;
    }
  }

  NumberAnimation {
    id: fromXAnim
    property: "x"
    duration: root.transitionTime
    easing.type: Easing.OutCubic
    onFinished: {
      if (target && target !== contentItems[currentIndex])
        target.visible = false;
      animating = false;
    }
  }

  NumberAnimation {
    id: toXAnim
    property: "x"
    duration: root.transitionTime
    easing.type: Easing.OutCubic
  }
}
