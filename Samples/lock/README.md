처음보는 메서드들이 다양하게 나와서 시간이 조금 소요되고 있습니다.

일단 Option은 쉽게 말해면 vector와 유사합니다.

- 저도 사용을 안해봐서 모르겠지만 doc이나 github를 보면 내부적으로 vec를 사용하는 것으로 확인하였습니다.

some같은 경우에는 인자를 하나 받는데 return값으로 해당 인자를 포함하는 Option을 반환한다고 합니다.

is_none같은 경우에는 해당 해당 option이 비여있는지를 확인하며 만약 안에 값이 없다면 true가 반환됩니다.

borrow_id같은 경우에는 신기하게도 내부로 들어오는 값으 id값을 반환하는데 반환되는 타입은 &ID입니다.
그러기 떄문에 key.for앞에 &을 붙여 주어야 동작합니다.

fill같은 경우에는 해당 값에 값을 넣어주는 역할을 합니다.
내부적으로 is_empty를 실행시키기 떄문에 안에 값이 비어있을떄에만 동작합니다.

extract는 fill과 반대로 데이터를 없앤뒤에 return합니다.

---

그러면 해당 코드는 이렇게 이해가 가능합니다.

create를 통해서 Key, Lock을 만듭니다.

이떄 Lock같은 경우에는 자물쇠역할로 obj를 담고 있는 객체가 되고

여기에 맞는 Key가 만들어 집니다.

이후 해당 자물쇠를 잠그고자 한다면 lock을 실행하고 어떠한 값을 담아서 잠그게 됩니다.

이후 다시 풀고자 한다면 자물쇠에 맞는 Key를 가져와서 풀면 됩니다.
