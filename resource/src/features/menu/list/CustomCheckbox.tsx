import { Checkbox, createStyles } from '@mantine/core';

const useStyles = createStyles((theme) => ({
  root: {
    display: 'flex',
    alignItems: 'center',
  },
  input: {
    backgroundColor: 'rgba(15, 15, 15, 0.95)',
    borderColor: 'rgba(255, 255, 255, 0.2)',
    '&:checked': { 
      backgroundColor: '#e0e0e0', 
      borderColor: '#e0e0e0' 
    },
  },
  inner: {
    '> svg > path': {
      fill: 'rgba(15, 15, 15, 0.95)',
    },
  },
}));

const CustomCheckbox: React.FC<{ checked: boolean }> = ({ checked }) => {
  const { classes } = useStyles();
  return (
    <Checkbox
      checked={checked}
      size="md"
      classNames={{ root: classes.root, input: classes.input, inner: classes.inner }}
    />
  );
};

export default CustomCheckbox;
